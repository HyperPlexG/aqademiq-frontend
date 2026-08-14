import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'dsp_chain.dart';
import 'models/bio_inputs.dart';
import 'models/preset_mode.dart';
import 'models/soundscape_params.dart';
import 'parameter_mapper.dart';
import 'scheduler.dart';
import 'sound_manifest.dart';
import 'stem_layer_manager.dart';

/// A hook that reshapes mapped params before user volumes are applied — lets
/// product modes derive variants of a preset (e.g. Flow = Focus with a calmer
/// pulse) without forking the engine.
typedef ParamsTransform = SoundscapeParams Function(SoundscapeParams params);

/// The Prism engine facade (PRISM_SOUND_ENGINE_ARCHITECTURE §7): singleton
/// lifecycle, preset switching with a 10 s stem crossfade + 5 s param lerp,
/// and the user volume multipliers.
/// Build identifier for the Prism engine, recorded on every focus session.
///
/// Sent to the backend as `engine_version` so a change in the soundscape can be
/// separated from a change in the users: without it, "focus improved" and "we
/// shipped a new engine" are indistinguishable in the analytics.
///
/// Bump this whenever the audible behaviour changes — presets, DSP chain,
/// scheduler, or the stem manifest.
const String kPrismEngineVersion = 'prism-1.0.0';

class AdaptiveSoundEngine extends ChangeNotifier {
  factory AdaptiveSoundEngine() => instance;

  AdaptiveSoundEngine._();

  static final AdaptiveSoundEngine instance = AdaptiveSoundEngine._();

  static const Duration _initTimeout = Duration(seconds: 10);
  static const Duration _initRecoveryDelay = Duration(milliseconds: 500);
  static const Duration _modeLerpDuration = Duration(seconds: 5);
  static const Duration _modeLerpStep = Duration(milliseconds: 100);

  bool _initialised = false;
  bool _playing = false;

  BioInputs _inputs = const BioInputs();
  PresetMode _mode = PresetMode.focus;
  ParamsTransform? _paramsTransform;

  double _userMasterVolume = 0.8;
  double _userEnvironmentVolume = 0.6;
  double _userPulseVolume = 0.4;

  StemLayerManager? _layerManager;
  Scheduler? _scheduler;
  DspChain? _dspChain;
  Timer? _lerpTimer;

  bool get isInitialised => _initialised;
  bool get isPlaying => _playing;
  PresetMode get currentMode => _mode;
  BioInputs get currentInputs => _inputs;
  SoundscapeParams get currentParams =>
      _scheduler?.currentParams ?? _computeParams();

  SoLoud get _soloud => SoLoud.instance;

  /// Brings up SoLoud (with the deinit → 500 ms → retry recovery path),
  /// loads the focus stems and activates the master filters.
  Future<void> init() async {
    if (_initialised) return;
    try {
      if (!_soloud.isInitialized) {
        try {
          await _soloud.init().timeout(_initTimeout);
        } on Exception {
          // Recovery: tear down and retry once (§7.1).
          _soloud.deinit();
          await Future<void>.delayed(_initRecoveryDelay);
          await _soloud.init().timeout(_initTimeout);
        }
      }
      // Global volume = preset gain × user master (both fades and immediate
      // sets target this same product, so neither overrides the other), and
      // voice headroom above the 4 layers so the looping pad and texture are
      // never stolen by overlapping one-shots.
      _soloud
        ..setGlobalVolume(_computeParams().masterGain)
        ..setMaxActiveVoiceCount(32);

      final layerManager =
          StemLayerManager(manifest: _manifestFor(_mode));
      await layerManager.loadStems();
      final dspChain = DspChain(layerManager: layerManager)..init();
      _layerManager = layerManager;
      _dspChain = dspChain;
      _scheduler =
          Scheduler(layerManager: layerManager, dspChain: dspChain);

      _initialised = true;
      notifyListeners();
    } on Exception catch (e) {
      debugPrint('Prism: engine init failed: $e');
      rethrow;
    }
  }

  SoundManifest _manifestFor(PresetMode mode) => switch (mode) {
        PresetMode.relax => SoundManifest.relaxMode(),
        PresetMode.breakMode => SoundManifest.breakMode(),
        PresetMode.focus || PresetMode.manual => SoundManifest.focusMode(),
      };

  SoundscapeParams _computeParams() {
    var params = ParameterMapper.map(_inputs, mode: _mode);
    final transform = _paramsTransform;
    if (transform != null) params = transform(params);
    return _applyUserVolumes(params);
  }

  /// §7.2 — texture level scales by the environment multiplier (in linear
  /// space, then back to dB), pulse level by the system multiplier, and the
  /// preset's master gain by the user master volume (fixing spec §18.10:
  /// without this the DSP masterGain fade would clobber the master slider).
  SoundscapeParams _applyUserVolumes(SoundscapeParams params) {
    final textureLinear =
        dbToLinear(params.textureVolumeDb) * _userEnvironmentVolume;
    return params.copyWith(
      textureVolumeDb: linearToDb(textureLinear),
      pulseVolume: (params.pulseVolume * _userPulseVolume).clamp(0.0, 1.0),
      masterGain: (params.masterGain * _userMasterVolume).clamp(0.0, 1.0),
    );
  }

  /// Starts the soundscape: pad + texture loops, clocks, DSP targets.
  Future<void> start() async {
    if (!_initialised || _playing) return;
    final params = _computeParams();
    await _layerManager!.start(params);
    _scheduler!.start(params);
    _dspChain!.updateParams(params);
    _playing = true;
    notifyListeners();
  }

  /// Freezes playback: clocks stop, loops fade to silence and pause.
  ///
  /// `_playing` flips *before* the 3 s fade so a [resume] tapped mid-fade is
  /// not gated out (the layer manager's own re-check then aborts the pause).
  Future<void> pause() async {
    if (!_playing) return;
    _lerpTimer?.cancel();
    _playing = false;
    _scheduler?.stop();
    notifyListeners();
    await _layerManager?.pause();
  }

  /// Resumes from [pause]: loops fade back, clocks restart.
  Future<void> resume() async {
    if (!_initialised || _playing) return;
    final params = _computeParams();
    _layerManager?.resume(params);
    _scheduler?.start(params);
    _playing = true;
    notifyListeners();
  }

  /// Graceful end-of-session stop (3 s fade).
  Future<void> stop() async {
    _lerpTimer?.cancel();
    _scheduler?.stop();
    _playing = false;
    await _layerManager?.stop();
    notifyListeners();
  }

  /// Immediate stop with no fade (logout / teardown).
  void forceStop() {
    _lerpTimer?.cancel();
    _scheduler?.stop();
    _playing = false;
    unawaited(_layerManager?.forceStop());
    notifyListeners();
  }

  void updateInputs(BioInputs inputs) {
    _inputs = inputs;
    _requeueParams();
  }

  void updateSingleInput(String key, dynamic value) {
    final v = value is num ? value.toDouble() : null;
    if (v == null) return;
    _inputs = switch (key) {
      'circadianPhase' => _inputs.copyWith(circadianPhase: v),
      'energyLevel' => _inputs.copyWith(energyLevel: v),
      'heartRate' => _inputs.copyWith(heartRate: v),
      'weatherIntensity' => _inputs.copyWith(weatherIntensity: v),
      'movementLevel' => _inputs.copyWith(movementLevel: v),
      'ultradianOverride' => _inputs.copyWith(ultradianOverride: v),
      _ => _inputs,
    };
    _requeueParams();
  }

  /// Switches preset: swaps the stem manifest (10 s crossfade when playing)
  /// and lerps the parameter bus to the new preset over 5 s (§7.3).
  ///
  /// [transform] optionally reshapes the mapped params for product-level
  /// variants of a preset; it stays in effect until the next mode switch.
  Future<void> setPresetMode(PresetMode mode,
      {ParamsTransform? transform}) async {
    final sameMode = mode == _mode && transform == _paramsTransform;
    _mode = mode;
    _paramsTransform = transform;
    if (!_initialised || sameMode) return;

    final start = currentParams;
    final target = _computeParams();

    await _layerManager?.updateManifest(
      _manifestFor(mode),
      target,
      playing: _playing,
    );

    if (!_playing) {
      _scheduler?.queueParams(target);
      notifyListeners();
      return;
    }

    _lerpTimer?.cancel();
    final steps =
        _modeLerpDuration.inMilliseconds ~/ _modeLerpStep.inMilliseconds;
    var step = 0;
    _lerpTimer = Timer.periodic(_modeLerpStep, (timer) {
      step++;
      final t = (step / steps).clamp(0.0, 1.0);
      _scheduler?.applyImmediately(start.lerp(target, t));
      if (step >= steps) timer.cancel();
    });
    notifyListeners();
  }

  /// Updates the persisted user volume multipliers (§7.2). Master volume
  /// scales the preset's masterGain on the SoLoud global bus; environment
  /// scales textures, pulse scales rhythm.
  void setUserVolumes({double? master, double? environment, double? pulse}) {
    if (master != null) _userMasterVolume = master.clamp(0.0, 1.0);
    if (environment != null) _userEnvironmentVolume = environment.clamp(0.0, 1.0);
    if (pulse != null) _userPulseVolume = pulse.clamp(0.0, 1.0);
    if (master != null && _soloud.isInitialized) {
      _soloud.setGlobalVolume(_computeParams().masterGain);
    }
    _requeueParams();
  }

  void _requeueParams() {
    if (_initialised && _playing) {
      _scheduler?.queueParams(_computeParams());
    }
  }

  /// Full teardown. The singleton can be [init]ed again afterwards.
  Future<void> shutdown() async {
    _lerpTimer?.cancel();
    await stop();
    _scheduler?.dispose();
    _dspChain?.dispose();
    await _layerManager?.dispose();
    _scheduler = null;
    _dspChain = null;
    _layerManager = null;
    _initialised = false;
    if (_soloud.isInitialized) _soloud.deinit();
  }
}
