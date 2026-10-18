/// The transport. `haptic_patterns.dart` decides what an event feels like;
/// this decides how to get that onto whatever motor is actually present.
///
/// Four rungs, in order:
///
///  1. **Core Haptics** (iPhone 8+) — intensity, sharpness, transients and
///     continuous events on a real timeline. Everything the vocabulary can say.
///  2. **`UIImpactFeedbackGenerator(intensity:)`** (older iPhones, iOS 13+) —
///     intensity survives, sharpness and multi-beat timing do not.
///  3. **Android `VibrationEffect`** — a waveform of durations and amplitudes.
///     Duration and intensity survive; sharpness does not exist on Android at
///     all and is approximated by pulse length.
///  4. **Flutter's five fixed effects** — the old behaviour, for desktop
///     embedders, tests, and any phone the channel cannot reach.
///
/// Rungs 1–3 live natively (`ios/Runner/HapticsPlugin.swift`,
/// `android/.../HapticsBridge.kt`); rung 4 is [_FallbackHaptics] below.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptic_patterns.dart';

/// Renders a [HapticPattern] on this device.
abstract interface class HapticDriver {
  /// Never throws, never rejects. Silence is an acceptable outcome; an error
  /// reaching the app because a motor is missing is not.
  Future<void> play(HapticPattern pattern);
}

/// The one the app uses. Swappable so tests can record patterns instead of
/// vibrating — see `test/haptic_patterns_test.dart`.
HapticDriver hapticDriver = const PlatformHapticDriver();

/// Restores the real driver. For `addTearDown` in tests that replaced it.
void resetHapticDriver() => hapticDriver = const PlatformHapticDriver();

/// Talks to the native side, and stops trying if nobody is listening.
class PlatformHapticDriver implements HapticDriver {
  const PlatformHapticDriver();

  static const MethodChannel channel = MethodChannel('aqademiq/haptics');

  /// Set once the channel proves absent — a desktop embedder, a unit test, an
  /// old build of the host app. After that every call goes straight to the
  /// fallback rather than paying for a round trip and an exception per haptic,
  /// of which there can be several per second during a scroll.
  ///
  /// Deliberately static: the driver is const, and the answer is a property of
  /// the process, not of any one instance.
  static bool _nativeMissing = false;

  @visibleForTesting
  static void resetNativeProbe() => _nativeMissing = false;

  @override
  Future<void> play(HapticPattern pattern) async {
    if (pattern.beats.isEmpty) return;
    if (!_nativeMissing) {
      try {
        await channel.invokeMethod<void>('play', {'beats': pattern.toWire()});
        return;
      } on MissingPluginException {
        // No native side at all. Remember, and never ask again.
        _nativeMissing = true;
      } on Object {
        // The native side exists but this pattern failed — a reset engine, a
        // motor busy with a system haptic. Fall through for this one call;
        // the next may well succeed, so the probe is left alone.
      }
    }
    await const _FallbackHaptics().play(pattern);
  }
}

/// Rung 4 — the old five-effect behaviour, kept honest.
///
/// It cannot express a pattern, so it plays the *strongest* beat and drops the
/// rest. That is the right lossy choice: the beat carrying the most energy is
/// the one carrying the meaning, and firing five `HapticFeedback` calls on a
/// timer would spend five platform round trips to produce a rattle.
class _FallbackHaptics implements HapticDriver {
  const _FallbackHaptics();

  @override
  Future<void> play(HapticPattern pattern) async {
    var peak = 0.0;
    var sharpness = 0.0;
    for (final beat in pattern.beats) {
      if (beat.intensity > peak) {
        peak = beat.intensity;
        sharpness = beat.sharpness;
      }
    }
    try {
      // A long dull beat is an error buzz; everything else is an impact whose
      // weight follows intensity. Sharpness only gets a vote at the bottom,
      // where a crisp light beat is a selection tick and a soft one is not.
      if (peak >= 0.6 && sharpness < 0.2) {
        await HapticFeedback.vibrate();
      } else if (peak >= 0.8) {
        await HapticFeedback.heavyImpact();
      } else if (peak >= 0.5) {
        await HapticFeedback.mediumImpact();
      } else if (sharpness >= 0.7) {
        await HapticFeedback.selectionClick();
      } else {
        await HapticFeedback.lightImpact();
      }
    } on Object {
      // Nothing behind `flutter/platform` either. Enrichment, so: silence.
    }
  }
}
