/// The transport: how an admitted pattern reaches whatever motor is present.
///
/// The native side (`ios/Runner/HapticsPlugin.swift`,
/// `android/.../HapticsBridge.kt`) picks the best rendering it can play:
///
///  * **iOS** — Core Haptics with the pattern's transients and intensity
///    curves; the system generators for `aq.success`, `aq.error` and phones
///    without Core Haptics.
///  * **Android** — composition primitives where the phone supports every one
///    a pattern uses, else the `performHapticFeedback` constant or predefined
///    effect, else the amplitude waveform, else a plain on/off rhythm. Every
///    vibration is tagged as touch feedback, so the phone's own touch-vibration
///    setting applies.
///
/// When there is no native side at all (a desktop embedder, a unit test),
/// [PlatformHapticDriver] plays the pattern's fallback preset through
/// Flutter's five effects.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'haptic_governor.dart';
import 'haptic_lexicon.dart';

/// The phone's state, as far as haptics care (§3, "Device state").
@immutable
class HapticDeviceState {
  const HapticDeviceState({this.lowPower = false, this.hot = false});

  final bool lowPower;
  final bool hot;

  /// Low Power Mode or a phone running hot drops Full down to Essential.
  bool get constrained => lowPower || hot;
}

/// Renders admitted patterns on this device.
abstract interface class HapticDriver {
  /// Fire and forget. Never throws: silence is an acceptable outcome, an error
  /// reaching the app because a motor is missing is not.
  void play(AdmittedHaptic haptic);

  /// Stop [id] if it is still playing, fading out over [fade] from [level]
  /// (0–1, how strong it was at the moment of stopping).
  void stop(int id, {Duration fade = Duration.zero, double level = 0});

  /// Low Power Mode and thermal state. Defaults to unconstrained.
  Future<HapticDeviceState> deviceState();

  /// Start or stop watching whether the phone lies face down, so bloom can
  /// switch to its desk-safe version with no delay at the moment it plays.
  void watchFaceDown({required bool on});
}

/// The one the app uses. Swappable so tests can record instead of vibrate.
HapticDriver hapticDriver = PlatformHapticDriver();

/// Restores the real driver. For `addTearDown` in tests that replaced it.
void resetHapticDriver() => hapticDriver = PlatformHapticDriver();

/// Talks to the native side, and stops trying if nobody is listening.
class PlatformHapticDriver implements HapticDriver {
  PlatformHapticDriver({TargetPlatform? platform}) : _platform = platform;

  static const MethodChannel channel = MethodChannel('aqademiq/haptics');

  final TargetPlatform? _platform;
  TargetPlatform get platform => _platform ?? defaultTargetPlatform;

  /// Set once the channel proves absent. After that every call goes straight
  /// to the fallback rather than paying for a round trip and an exception per
  /// haptic. Static: the answer is a property of the process.
  static bool _nativeMissing = false;

  @visibleForTesting
  static void resetNativeProbe() => _nativeMissing = false;

  @override
  void play(AdmittedHaptic haptic) {
    final spec = haptic.spec;
    if (spec.ios.isEmpty && spec.android.isEmpty && spec.androidWave == null && spec.iosSystem == null) return;
    if (_nativeMissing) {
      _fallback(spec.fallback);
      return;
    }
    unawaited(channel
        .invokeMethod<void>('play', {
          'id': haptic.id,
          ...spec.toWire(platform: platform, faceDownAlt: haptic.faceDownAlt),
        })
        .catchError((Object e) {
          if (e is MissingPluginException) _nativeMissing = true;
          // A native side that exists but refused this pattern: one preset
          // still beats nothing. The next pattern may well succeed.
          _fallback(spec.fallback);
        }));
  }

  @override
  void stop(int id, {Duration fade = Duration.zero, double level = 0}) {
    if (_nativeMissing) return;
    unawaited(channel
        .invokeMethod<void>('stop', {'id': id, 'fadeMs': fade.inMilliseconds, 'level': level})
        .catchError((Object _) {}));
  }

  @override
  Future<HapticDeviceState> deviceState() async {
    if (_nativeMissing) return const HapticDeviceState();
    try {
      final m = await channel.invokeMapMethod<String, Object?>('deviceState');
      return HapticDeviceState(lowPower: m?['lowPower'] == true, hot: m?['hot'] == true);
    } on Object {
      return const HapticDeviceState();
    }
  }

  @override
  void watchFaceDown({required bool on}) {
    if (_nativeMissing) return;
    unawaited(channel.invokeMethod<void>('watchFaceDown', {'on': on}).catchError((Object _) {}));
  }

  /// The spec's "Fallback" row, through Flutter's five effects.
  static void _fallback(Fallback f) {
    final effect = switch (f) {
      Fallback.none => null,
      Fallback.selection => HapticFeedback.selectionClick,
      Fallback.light => HapticFeedback.lightImpact,
      Fallback.medium || Fallback.success => HapticFeedback.mediumImpact,
      Fallback.heavy => HapticFeedback.heavyImpact,
      Fallback.error => HapticFeedback.vibrate,
    };
    if (effect != null) unawaited(effect().catchError((Object _) {}));
  }
}
