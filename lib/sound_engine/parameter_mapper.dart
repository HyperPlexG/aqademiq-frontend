import 'dart:math' as math;

import 'models/bio_inputs.dart';
import 'models/preset_mode.dart';
import 'models/soundscape_params.dart';

/// Pure `BioInputs → SoundscapeParams` mapping
/// (PRISM_SOUND_ENGINE_ARCHITECTURE §6).
///
/// Non-manual modes short-circuit to factory presets (heart rate still seeds
/// the BPM on focus/relax); [PresetMode.manual] runs the full bio formulas.
abstract final class ParameterMapper {
  static SoundscapeParams map(
    BioInputs inputs, {
    PresetMode mode = PresetMode.manual,
  }) {
    switch (mode) {
      case PresetMode.focus:
        return SoundscapeParams.focus(heartRate: inputs.heartRate);
      case PresetMode.relax:
        return SoundscapeParams.relax(heartRate: inputs.heartRate);
      case PresetMode.breakMode:
        return SoundscapeParams.breakMode();
      case PresetMode.manual:
        return _mapManual(inputs);
    }
  }

  /// The full bio-driven blueprint (§6.2).
  static SoundscapeParams _mapManual(BioInputs inputs) {
    final hrNorm = inputs.heartRateNormalised;
    final circadian = inputs.circadianPhase.clamp(0.0, 1.0);
    final weather = inputs.weatherIntensity.clamp(0.0, 1.0);
    final movement = inputs.movementLevel.clamp(0.0, 1.0);
    final energy = inputs.energyLevel.clamp(0.0, 1.0);
    final ultradian = inputs.ultradianOverride ?? inputs.computeUltradian();

    double bell(double x) => math.sin(x * math.pi);

    final masterEnergy =
        (0.3 * circadian + 0.3 * ultradian + 0.4 * hrNorm).clamp(0.0, 1.0);
    final hrOverride = inputs.heartRate > 110;

    final double pulseVolume;
    if (hrOverride) {
      pulseVolume = 0.3;
    } else if (circadian < 0.2) {
      pulseVolume = ((circadian / 0.2) * 0.6).clamp(0.0, 0.8);
    } else {
      pulseVolume = 0.6;
    }

    return SoundscapeParams(
      // Pad
      padCutoff:
          hrOverride ? 400 : (250 + 2250 * circadian).clamp(250.0, 2500.0),
      padSaturation: (15 * bell(ultradian)).clamp(0.0, 15.0),
      padDetune: (15 * (1 - hrNorm)).clamp(0.0, 15.0),
      padReverbWet: (0.2 + 0.4 * (1 - weather)).clamp(0.2, 0.6),
      // Texture
      textureVolumeDb: (-30 + 18 * movement).clamp(-30.0, -12.0),
      textureBrownNoise: hrNorm > 0.6,
      textureStereoWidthMs: (15 * (1 - circadian)).clamp(0.0, 15.0),
      // Pulse (iso-principle)
      pulseBpm: (inputs.heartRate - 10).clamp(50.0, 150.0),
      pulseAttackMs: (50 - 45 * bell(ultradian)).clamp(5.0, 50.0),
      pulseDensity: (1 + movement).clamp(1.0, 2.0),
      pulseVolume: pulseVolume,
      // Spark
      sparkTriggerProb:
          hrOverride ? 0.35 : (0.05 + 0.35 * (1 - hrNorm)).clamp(0.05, 0.40),
      sparkPanLfoRate: (0.1 + 0.4 * weather).clamp(0.1, 0.5),
      sparkOctave: (ultradian * 2).round().clamp(0, 2),
      sparkDelayFeedback: (0.1 + 0.5 * (1 - movement)).clamp(0.1, 0.6),
      // Global
      masterLpfCutoff: (600 + 17400 * masterEnergy).clamp(600.0, 18000.0),
      masterGain: (0.5 + energy * 0.5).clamp(0.3, 1.0),
    );
  }
}
