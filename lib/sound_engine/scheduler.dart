import 'dart:async';

import 'dsp_chain.dart';
import 'models/soundscape_params.dart';
import 'stem_layer_manager.dart';

/// The engine's clocks (PRISM_SOUND_ENGINE_ARCHITECTURE §9):
///
/// * a BPM beat clock firing pulse one-shots (plus half-beat triggers when
///   `pulseDensity > 1.5`),
/// * a 1 Hz spark clock,
/// * 4-bar (16-beat) quantisation for queued parameter changes — only BPM
///   jumps > 1 apply immediately (clock restart).
class Scheduler {
  Scheduler({required this.layerManager, required this.dspChain});

  static const int _beatsPerPhrase = 16; // 4 bars × 4 beats.
  static const Duration _sparkInterval = Duration(seconds: 1);
  static const double _bpmEpsilon = 1;

  final StemLayerManager layerManager;
  final DspChain dspChain;

  Timer? _beatTimer;
  Timer? _sparkTimer;
  int _beatCount = 0;

  SoundscapeParams _currentParams = const SoundscapeParams();
  SoundscapeParams? _pendingParams;

  bool get isRunning => _beatTimer != null;

  SoundscapeParams get currentParams => _currentParams;

  void start(SoundscapeParams params) {
    _currentParams = params;
    _pendingParams = null;
    _beatCount = 0;
    _startBeatClock();
    _sparkTimer?.cancel();
    _sparkTimer = Timer.periodic(
      _sparkInterval,
      (_) => unawaited(layerManager.tryTriggerSpark(_currentParams)),
    );
  }

  void _startBeatClock() {
    _beatTimer?.cancel();
    final bpm = _currentParams.pulseBpm.clamp(20.0, 300.0);
    final intervalMs = (60000 / bpm).round();
    _beatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _beatCount++;
      unawaited(layerManager.triggerPulse(_currentParams));
      if (_currentParams.pulseDensity > 1.5) {
        Timer(Duration(milliseconds: intervalMs ~/ 2), () {
          if (isRunning) {
            unawaited(layerManager.triggerPulse(_currentParams));
          }
        });
      }
      if (_beatCount % _beatsPerPhrase == 0) _applyPendingParams();
    });
  }

  /// Queues a parameter snapshot. BPM changes beyond ±1 restart the beat
  /// clock immediately; everything else waits for the 16-beat boundary.
  void queueParams(SoundscapeParams params) {
    _pendingParams = params;
    if ((params.pulseBpm - _currentParams.pulseBpm).abs() > _bpmEpsilon) {
      _currentParams = _currentParams.copyWith(pulseBpm: params.pulseBpm);
      if (isRunning) _startBeatClock();
    }
  }

  void _applyPendingParams() {
    final pending = _pendingParams;
    if (pending == null) return;
    _pendingParams = null;
    _currentParams = pending;
    layerManager.updateParams(pending);
    dspChain.updateParams(pending);
  }

  /// Applies whatever is queued right now, skipping the phrase boundary
  /// (used by the engine's 5 s mode lerp for smooth continuous motion).
  void applyImmediately(SoundscapeParams params) {
    _pendingParams = null;
    final bpmChanged =
        (params.pulseBpm - _currentParams.pulseBpm).abs() > _bpmEpsilon;
    _currentParams = params;
    if (bpmChanged && isRunning) _startBeatClock();
    layerManager.updateParams(params);
    dspChain.updateParams(params);
  }

  void stop() {
    _beatTimer?.cancel();
    _beatTimer = null;
    _sparkTimer?.cancel();
    _sparkTimer = null;
    _beatCount = 0;
    _pendingParams = null;
  }

  void dispose() => stop();
}
