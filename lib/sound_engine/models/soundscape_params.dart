import 'dart:math' as math;

/// dB → linear amplitude (`10^(db/20)`).
double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

/// Linear amplitude → dB, clamped to avoid `log(0)`.
double linearToDb(double linear) =>
    20 * (math.log(linear.clamp(1e-9, 2.0)) / math.ln10);

/// The engine control surface — every subsystem consumes this struct
/// (PRISM_SOUND_ENGINE_ARCHITECTURE §5.5).
class SoundscapeParams {
  const SoundscapeParams({
    // Pad
    this.padCutoff = 1200,
    this.padSaturation = 0,
    this.padDetune = 0,
    this.padReverbWet = 0.4,
    // Texture
    this.textureVolumeDb = -18,
    this.textureBrownNoise = false,
    this.textureStereoWidthMs = 0,
    // Pulse
    this.pulseBpm = 72,
    this.pulseAttackMs = 20,
    this.pulseDensity = 1,
    this.pulseVolume = 0.6,
    // Spark
    this.sparkTriggerProb = 0.2,
    this.sparkPanLfoRate = 0.2,
    this.sparkOctave = 1,
    this.sparkDelayFeedback = 0.3,
    // Global
    this.masterLpfCutoff = 8000,
    this.masterGain = 0.8,
  });

  /// Focus preset (§6.1): bright open LPF, dense pulses near HR+5 BPM.
  factory SoundscapeParams.focus({double heartRate = 72}) {
    return SoundscapeParams(
      masterLpfCutoff: 18000,
      pulseAttackMs: 5,
      sparkOctave: 2,
      pulseBpm: (heartRate + 5).clamp(60.0, 90.0),
      masterGain: 1,
      pulseVolume: 0.8,
      pulseDensity: 2,
      sparkTriggerProb: 0.3,
      padCutoff: 2500,
    );
  }

  /// Relax / Mellow preset (§6.1): dark LPF, muted rhythm, wide and wet.
  factory SoundscapeParams.relax({double heartRate = 72}) {
    return SoundscapeParams(
      masterLpfCutoff: 600,
      textureStereoWidthMs: 15,
      textureBrownNoise: true,
      pulseBpm: (heartRate - 10).clamp(60.0, 90.0),
      sparkTriggerProb: 0.05,
      masterGain: 0.5,
      pulseVolume: 0,
      pulseAttackMs: 40,
      sparkOctave: 0,
      padCutoff: 600,
      padReverbWet: 0.55,
      sparkPanLfoRate: 0.1,
      sparkDelayFeedback: 0.5,
      padDetune: 12,
    );
  }

  /// Break preset (§6.1): slow 60 BPM, soft pulse, very wet reverb.
  factory SoundscapeParams.breakMode() {
    return const SoundscapeParams(
      pulseAttackMs: 50,
      padDetune: 15,
      sparkDelayFeedback: 0.6,
      masterLpfCutoff: 3000,
      pulseBpm: 60,
      pulseVolume: 0.3,
      padReverbWet: 0.6,
      textureVolumeDb: -24,
    );
  }

  // Pad
  /// Pad low-pass cutoff intent, Hz (250–2500). Not yet applied per-voice.
  final double padCutoff;

  /// Pad saturation intent, % (0–15). Not yet applied.
  final double padSaturation;

  /// Pad detune intent, cents (0–15). Not yet applied.
  final double padDetune;

  /// Master Freeverb wet amount, linear 0.2–0.6. Applied via `DspChain`.
  final double padReverbWet;

  // Texture
  /// Texture loop level in dB (−30 to −12).
  final double textureVolumeDb;

  /// Brown (true) vs pink (false) noise-colour selection for the texture stem.
  final bool textureBrownNoise;

  /// Haas stereo-width intent, ms (0–15). Not yet applied.
  final double textureStereoWidthMs;

  // Pulse
  /// Beat clock, BPM (~50–150).
  final double pulseBpm;

  /// Pulse envelope attack intent, ms (5–50). Not yet applied.
  final double pulseAttackMs;

  /// 1–2; above 1.5 the scheduler adds half-beat (eighth-note) triggers.
  final double pulseDensity;

  /// Pulse one-shot volume, linear 0–1.
  final double pulseVolume;

  // Spark
  /// Per-second trigger probability (0.05–0.40).
  final double sparkTriggerProb;

  /// Spark pan LFO rate, Hz (0.1–0.5).
  final double sparkPanLfoRate;

  /// 0–2 → C4/C5/C6 register intent. Assets carry no octave metadata yet, so
  /// selection is uniform (documented gap, §18.2).
  final int sparkOctave;

  /// Spark delay feedback intent, linear (0.1–0.6). Not yet applied.
  final double sparkDelayFeedback;

  // Global
  /// Master biquad LPF cutoff, Hz (600–18000).
  final double masterLpfCutoff;

  /// Master gain, linear 0–1 (drives `fadeGlobalVolume`).
  final double masterGain;

  /// Linear interpolation of every continuous field; [textureBrownNoise]
  /// switches at `t ≥ 0.5`, [sparkOctave] lerps then rounds (§5.5).
  SoundscapeParams lerp(SoundscapeParams other, double t) {
    double l(double a, double b) => a + (b - a) * t;
    return SoundscapeParams(
      padCutoff: l(padCutoff, other.padCutoff),
      padSaturation: l(padSaturation, other.padSaturation),
      padDetune: l(padDetune, other.padDetune),
      padReverbWet: l(padReverbWet, other.padReverbWet),
      textureVolumeDb: l(textureVolumeDb, other.textureVolumeDb),
      textureBrownNoise: t < 0.5 ? textureBrownNoise : other.textureBrownNoise,
      textureStereoWidthMs: l(textureStereoWidthMs, other.textureStereoWidthMs),
      pulseBpm: l(pulseBpm, other.pulseBpm),
      pulseAttackMs: l(pulseAttackMs, other.pulseAttackMs),
      pulseDensity: l(pulseDensity, other.pulseDensity),
      pulseVolume: l(pulseVolume, other.pulseVolume),
      sparkTriggerProb: l(sparkTriggerProb, other.sparkTriggerProb),
      sparkPanLfoRate: l(sparkPanLfoRate, other.sparkPanLfoRate),
      sparkOctave:
          l(sparkOctave.toDouble(), other.sparkOctave.toDouble()).round(),
      sparkDelayFeedback: l(sparkDelayFeedback, other.sparkDelayFeedback),
      masterLpfCutoff: l(masterLpfCutoff, other.masterLpfCutoff),
      masterGain: l(masterGain, other.masterGain),
    );
  }

  SoundscapeParams copyWith({
    double? padCutoff,
    double? padSaturation,
    double? padDetune,
    double? padReverbWet,
    double? textureVolumeDb,
    bool? textureBrownNoise,
    double? textureStereoWidthMs,
    double? pulseBpm,
    double? pulseAttackMs,
    double? pulseDensity,
    double? pulseVolume,
    double? sparkTriggerProb,
    double? sparkPanLfoRate,
    int? sparkOctave,
    double? sparkDelayFeedback,
    double? masterLpfCutoff,
    double? masterGain,
  }) {
    return SoundscapeParams(
      padCutoff: padCutoff ?? this.padCutoff,
      padSaturation: padSaturation ?? this.padSaturation,
      padDetune: padDetune ?? this.padDetune,
      padReverbWet: padReverbWet ?? this.padReverbWet,
      textureVolumeDb: textureVolumeDb ?? this.textureVolumeDb,
      textureBrownNoise: textureBrownNoise ?? this.textureBrownNoise,
      textureStereoWidthMs: textureStereoWidthMs ?? this.textureStereoWidthMs,
      pulseBpm: pulseBpm ?? this.pulseBpm,
      pulseAttackMs: pulseAttackMs ?? this.pulseAttackMs,
      pulseDensity: pulseDensity ?? this.pulseDensity,
      pulseVolume: pulseVolume ?? this.pulseVolume,
      sparkTriggerProb: sparkTriggerProb ?? this.sparkTriggerProb,
      sparkPanLfoRate: sparkPanLfoRate ?? this.sparkPanLfoRate,
      sparkOctave: sparkOctave ?? this.sparkOctave,
      sparkDelayFeedback: sparkDelayFeedback ?? this.sparkDelayFeedback,
      masterLpfCutoff: masterLpfCutoff ?? this.masterLpfCutoff,
      masterGain: masterGain ?? this.masterGain,
    );
  }
}
