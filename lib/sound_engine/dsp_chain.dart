import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_soloud/flutter_soloud.dart';

import 'models/soundscape_params.dart';
import 'stem_layer_manager.dart';

/// The master bus (PRISM_SOUND_ENGINE_ARCHITECTURE §10): a global biquad
/// resonant LPF + Freeverb, master-gain fades, and the spark pan LFO.
class DspChain {
  DspChain({this.layerManager});

  static const Duration _paramFade = Duration(seconds: 15);
  static const Duration _lfoTick = Duration(milliseconds: 50);

  /// Wired so the pan LFO actually reaches spark voices (fixes §18.4).
  final StemLayerManager? layerManager;

  Timer? _lfoTimer;
  double _lfoPhase = 0;
  double _lfoRateHz = 0.2;
  double _panLfoValue = 0;

  bool _active = false;

  SoLoud get _soloud => SoLoud.instance;

  /// Current LFO output in −0.7…0.7.
  double get panLfoValue => _panLfoValue;

  /// Activates the global filters with the §10.1 defaults.
  void init() {
    final lpf = _soloud.filters.biquadResonantFilter;
    if (!lpf.isActive) lpf.activate();
    lpf.wet.value = 1.0;
    lpf.frequency.value = 8000;
    lpf.resonance.value = 2.0;

    final reverb = _soloud.filters.freeverbFilter;
    if (!reverb.isActive) reverb.activate();
    reverb.wet.value = 0.4;
    reverb.roomSize.value = 0.5;
    reverb.damp.value = 0.5;

    _active = true;
    _startLfo();
  }

  void _startLfo() {
    _lfoTimer?.cancel();
    _lfoTimer = Timer.periodic(_lfoTick, (_) {
      _lfoPhase += _lfoRateHz * 0.05 * 2 * math.pi;
      _panLfoValue = math.sin(_lfoPhase) * 0.7;
      layerManager?.applyPanLfo(_panLfoValue);
    });
  }

  /// 15 s fades toward the new targets: LPF cutoff, reverb wet, master gain.
  void updateParams(SoundscapeParams params) {
    if (!_active) return;
    _soloud.filters.biquadResonantFilter.frequency.fadeFilterParameter(
      to: params.masterLpfCutoff.clamp(200.0, 20000.0),
      time: _paramFade,
    );
    _soloud.filters.freeverbFilter.wet.fadeFilterParameter(
      to: params.padReverbWet.clamp(0.0, 1.0),
      time: _paramFade,
    );
    _soloud.fadeGlobalVolume(params.masterGain.clamp(0.0, 1.0), _paramFade);
    _lfoRateHz = params.sparkPanLfoRate.clamp(0.05, 2.0);
  }

  void dispose() {
    _lfoTimer?.cancel();
    _lfoTimer = null;
    if (_active && _soloud.isInitialized) {
      final lpf = _soloud.filters.biquadResonantFilter;
      if (lpf.isActive) lpf.deactivate();
      final reverb = _soloud.filters.freeverbFilter;
      if (reverb.isActive) reverb.deactivate();
    }
    _active = false;
  }
}
