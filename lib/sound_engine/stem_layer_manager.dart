import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'models/soundscape_params.dart';
import 'models/stem.dart';
import 'sound_manifest.dart';

/// Owns every SoLoud voice: the always-on pad/texture loops and the pulse /
/// spark one-shots (PRISM_SOUND_ENGINE_ARCHITECTURE §8).
class StemLayerManager {
  StemLayerManager({required SoundManifest manifest, math.Random? random})
      : _manifest = manifest,
        _random = random ?? math.Random();

  static const Duration _defaultFade = Duration(seconds: 10);
  static const Duration _quickFade = Duration(seconds: 3);
  static const Duration _startFade = Duration(seconds: 5);
  static const Duration _sparkMinGap = Duration(seconds: 3);
  static const double _padVolume = 0.6;
  static const double _sparkVolume = 0.4;
  static const double _sparkPanDepth = 0.7;

  /// Cap on simultaneously ringing spark voices (§14 guidance).
  static const int _maxConcurrentSparks = 8;

  final math.Random _random;
  SoundManifest _manifest;

  /// Loaded sources keyed by asset path — shared across manifests since all
  /// modes reuse the same focus-mode WAV files.
  final Map<String, AudioSource> _sources = {};

  SoundHandle? _padHandle;
  SoundHandle? _textureHandle;
  final List<SoundHandle> _activeSparkHandles = [];

  /// Each ringing spark's random placement, so the pan LFO modulates around
  /// it instead of integrating drift into it.
  final Map<SoundHandle, double> _sparkBasePan = {};

  DateTime _lastSparkAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _paused = false;

  SoLoud get _soloud => SoLoud.instance;

  /// Loads every stem of the current manifest that is not already cached.
  Future<void> loadStems() async {
    for (final stem in _manifest.allStems) {
      if (_sources.containsKey(stem.assetPath)) continue;
      try {
        _sources[stem.assetPath] = await _soloud.loadAsset(stem.assetPath);
      } on Exception catch (e) {
        debugPrint('Prism: failed to load ${stem.assetPath}: $e');
      }
    }
  }

  /// Starts the always-on layers: a random pad and the noise-colour-matched
  /// texture, both fading in over 5 s.
  Future<void> start(SoundscapeParams params) async {
    _paused = false;
    await _startPad(fade: _startFade);
    await _startTexture(params, fade: _startFade);
  }

  Future<void> _startPad({required Duration fade}) async {
    if (_manifest.pads.isEmpty) return;
    final stem = _manifest.pads[_random.nextInt(_manifest.pads.length)];
    final source = _sources[stem.assetPath];
    if (source == null) return;
    final handle = await _soloud.play(source, volume: 0, looping: true);
    _padHandle = handle;
    _soloud
      ..setProtectVoice(handle, true) // never stolen by one-shots
      ..fadeVolume(handle, _padVolume, fade);
  }

  Future<void> _startTexture(SoundscapeParams params,
      {required Duration fade}) async {
    final stem = _selectTexture(params);
    if (stem == null) return;
    final source = _sources[stem.assetPath];
    if (source == null) return;
    final handle = await _soloud.play(source, volume: 0, looping: true);
    _textureHandle = handle;
    _soloud
      ..setProtectVoice(handle, true) // never stolen by one-shots
      ..fadeVolume(handle, _textureTarget(params), fade);
  }

  /// Noise-colour selection by [Stem.noteName] — the v1 `assetPath.contains`
  /// bug is fixed here per §18.1.
  Stem? _selectTexture(SoundscapeParams params) {
    if (_manifest.textures.isEmpty) return null;
    final wanted = params.textureBrownNoise ? 'brown' : 'pink';
    for (final t in _manifest.textures) {
      if (t.noteName == wanted) return t;
    }
    return _manifest.textures.first;
  }

  double _textureTarget(SoundscapeParams params) =>
      dbToLinear(params.textureVolumeDb).clamp(0.0, 1.0);

  /// Long-fade the loop levels toward the (possibly new) params.
  void updateParams(SoundscapeParams params) {
    final pad = _padHandle;
    if (pad != null && _soloud.getIsValidVoiceHandle(pad)) {
      _soloud.fadeVolume(pad, _padVolume, _defaultFade);
    }
    final texture = _textureHandle;
    if (texture != null && _soloud.getIsValidVoiceHandle(texture)) {
      _soloud.fadeVolume(texture, _textureTarget(params), _defaultFade);
    }
  }

  /// One pulse one-shot, weighted-random pick by [Stem.probability]
  /// (called by the Scheduler on each beat).
  Future<void> triggerPulse(SoundscapeParams params) async {
    if (_paused || _manifest.pulses.isEmpty) return;
    final volume = params.pulseVolume.clamp(0.0, 1.0);
    if (volume <= 0) return;
    final stem = _weightedRandom(_manifest.pulses);
    final source = _sources[stem.assetPath];
    if (source == null) return;
    await _soloud.play(source, volume: volume);
  }

  Stem _weightedRandom(List<Stem> stems) {
    final total = stems.fold<double>(0, (sum, s) => sum + s.probability);
    var roll = _random.nextDouble() * total;
    for (final stem in stems) {
      roll -= stem.probability;
      if (roll <= 0) return stem;
    }
    return stems.last;
  }

  /// Maybe fires a spark one-shot: probability [SoundscapeParams
  /// .sparkTriggerProb], minimum 3 s gap, volume 0.4, random pan ±0.7
  /// (called ~1 Hz by the Scheduler).
  Future<void> tryTriggerSpark(SoundscapeParams params) async {
    if (_paused || _manifest.sparks.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastSparkAt) < _sparkMinGap) return;
    if (_random.nextDouble() > params.sparkTriggerProb) return;

    _cleanupSparks();
    if (_activeSparkHandles.length >= _maxConcurrentSparks) return;

    final octave = 4 + params.sparkOctave;
    final candidates = _manifest.sparksByOctave(octave);
    final stem = candidates[_random.nextInt(candidates.length)];
    final source = _sources[stem.assetPath];
    if (source == null) return;

    final pan = (_random.nextDouble() * 2 - 1) * _sparkPanDepth;
    final handle =
        await _soloud.play(source, volume: _sparkVolume, pan: pan);
    _lastSparkAt = now;
    _activeSparkHandles.add(handle);
    _sparkBasePan[handle] = pan;
  }

  /// Gentle pan wobble on ringing sparks — wires the previously dangling pan
  /// LFO (§18.4): each voice keeps its stored random placement, modulated
  /// ±0.3 around it (absolute set, never accumulated, so no drift).
  void applyPanLfo(double lfoValue) {
    _cleanupSparks();
    for (final handle in _activeSparkHandles) {
      final base = _sparkBasePan[handle] ?? 0.0;
      // lfoValue swings ±0.7; rescale to the documented ±0.3 wobble.
      _soloud.setPan(handle, (base + lfoValue * (0.3 / 0.7)).clamp(-1.0, 1.0));
    }
  }

  void _cleanupSparks() {
    _activeSparkHandles
        .removeWhere((h) => !_soloud.getIsValidVoiceHandle(h));
    _sparkBasePan.removeWhere((h, _) => !_soloud.getIsValidVoiceHandle(h));
  }

  /// Crossfades to a new mode's stems over 10 s (§8.6): the old pad/texture
  /// fade out and stop while fresh voices start at the new params.
  Future<void> updateManifest(
    SoundManifest manifest,
    SoundscapeParams params, {
    required bool playing,
  }) async {
    _manifest = manifest;
    await loadStems();
    if (!playing) return;

    final oldPad = _padHandle;
    final oldTexture = _textureHandle;
    _padHandle = null;
    _textureHandle = null;

    await _startPad(fade: _defaultFade);
    await _startTexture(params, fade: _defaultFade);

    for (final handle in [oldPad, oldTexture]) {
      if (handle == null || !_soloud.getIsValidVoiceHandle(handle)) continue;
      _soloud.fadeVolume(handle, 0, _defaultFade);
      unawaited(
        Future<void>.delayed(_defaultFade + const Duration(milliseconds: 200))
            .then((_) async {
          if (_soloud.getIsValidVoiceHandle(handle)) {
            await _soloud.stop(handle);
          }
        }),
      );
    }
  }

  /// 3 s fade to silence, then pauses the loop voices so they can resume.
  Future<void> pause() async {
    _paused = true;
    final handles = [_padHandle, _textureHandle, ..._activeSparkHandles];
    for (final handle in handles) {
      if (handle == null || !_soloud.getIsValidVoiceHandle(handle)) continue;
      _soloud.fadeVolume(handle, 0, _quickFade);
    }
    await Future<void>.delayed(_quickFade);
    if (!_paused) return; // Resumed during the fade.
    for (final handle in handles) {
      if (handle == null || !_soloud.getIsValidVoiceHandle(handle)) continue;
      _soloud.setPause(handle, true);
    }
  }

  /// Un-pauses and fades the loops back to their targets over 3 s.
  void resume(SoundscapeParams params) {
    _paused = false;
    final pad = _padHandle;
    if (pad != null && _soloud.getIsValidVoiceHandle(pad)) {
      _soloud
        ..setPause(pad, false)
        ..fadeVolume(pad, _padVolume, _quickFade);
    }
    final texture = _textureHandle;
    if (texture != null && _soloud.getIsValidVoiceHandle(texture)) {
      _soloud
        ..setPause(texture, false)
        ..fadeVolume(texture, _textureTarget(params), _quickFade);
    }
    for (final handle in _activeSparkHandles) {
      if (_soloud.getIsValidVoiceHandle(handle)) {
        _soloud.setPause(handle, false);
      }
    }
  }

  /// 3 s fade-out, then stops every voice. Handles are detached up front so
  /// a session started during the fade can't have its fresh voices clobbered.
  Future<void> stop() async {
    _paused = true;
    final handles = _detachHandles();
    for (final handle in handles) {
      if (_soloud.getIsValidVoiceHandle(handle)) {
        _soloud.fadeVolume(handle, 0, _quickFade);
      }
    }
    await Future<void>.delayed(_quickFade + const Duration(milliseconds: 100));
    await _stopAll(handles);
  }

  /// Immediate stop (logout / teardown), no fade.
  Future<void> forceStop() async {
    _paused = true;
    await _stopAll(_detachHandles());
  }

  /// Clears the voice fields and returns what they held.
  List<SoundHandle> _detachHandles() {
    final handles = [
      ?_padHandle,
      ?_textureHandle,
      ..._activeSparkHandles,
    ];
    _padHandle = null;
    _textureHandle = null;
    _activeSparkHandles.clear();
    _sparkBasePan.clear();
    return handles;
  }

  Future<void> _stopAll(List<SoundHandle> handles) async {
    for (final handle in handles) {
      if (_soloud.getIsValidVoiceHandle(handle)) {
        await _soloud.stop(handle);
      }
    }
  }

  /// Stops voices and releases the cached sources.
  Future<void> dispose() async {
    await forceStop();
    for (final source in _sources.values) {
      await _soloud.disposeSource(source);
    }
    _sources.clear();
  }
}
