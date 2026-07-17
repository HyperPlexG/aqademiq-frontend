import 'dart:math' as math;

/// Sensor contract for the adaptive mapper
/// (PRISM_SOUND_ENGINE_ARCHITECTURE §5.4).
///
/// Nothing feeds live sensors yet — presets dominate — but the contract is
/// kept so a future pass can wire Health / weather / movement data into
/// `PresetMode.manual` without touching the engine.
class BioInputs {
  const BioInputs({
    this.circadianPhase = 0.5,
    this.energyLevel = 0.5,
    this.heartRate = 72,
    this.weatherIntensity = 0.3,
    this.movementLevel = 0.2,
    this.ultradianOverride,
  });

  /// 0 = midnight, 0.5 = noon, 1 = midnight again.
  final double circadianPhase;

  /// 0 = asleep, 1 = peak energy.
  final double energyLevel;

  /// Beats per minute.
  final double heartRate;

  /// 0 = clear skies, 1 = storm.
  final double weatherIntensity;

  /// 0 = still, 1 = running.
  final double movementLevel;

  /// Optional 0–1 override; when null the 90-minute wall-clock cycle is used.
  final double? ultradianOverride;

  /// Heart rate normalised into 0–1 over the 40–160 BPM band.
  double get heartRateNormalised => ((heartRate - 40) / 120).clamp(0.0, 1.0);

  /// 90-minute ultradian cycle derived from the wall clock: a bell curve
  /// (`sin(phase·π)`) peaking mid-cycle.
  double computeUltradian({DateTime? now}) {
    final t = now ?? DateTime.now();
    final minutesSinceMidnight = t.hour * 60 + t.minute;
    final phase = (minutesSinceMidnight % 90) / 90.0;
    return math.sin(phase * math.pi);
  }

  BioInputs copyWith({
    double? circadianPhase,
    double? energyLevel,
    double? heartRate,
    double? weatherIntensity,
    double? movementLevel,
    double? ultradianOverride,
  }) {
    return BioInputs(
      circadianPhase: circadianPhase ?? this.circadianPhase,
      energyLevel: energyLevel ?? this.energyLevel,
      heartRate: heartRate ?? this.heartRate,
      weatherIntensity: weatherIntensity ?? this.weatherIntensity,
      movementLevel: movementLevel ?? this.movementLevel,
      ultradianOverride: ultradianOverride ?? this.ultradianOverride,
    );
  }
}
