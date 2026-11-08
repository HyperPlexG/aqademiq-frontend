import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/repositories/focus_repository.dart';
import '../../features/settings/providers/haptic_settings_provider.dart';
import 'haptic_driver.dart';
import 'haptic_governor.dart';
import 'haptic_lexicon.dart';
import 'haptic_moments.dart';

export 'haptic_moments.dart' show HapticMoment, deleteAccountHoldTime, thawEverythingHoldTime;

/// What the rest of the app talks to.
///
/// Screens and controllers say which moment happened — never which pattern,
/// never a platform. `haptic_moments.dart` says how each moment feels, the
/// governor decides whether it plays, and the driver gets it to the motor.
///
/// ```dart
/// ref.read(hapticsProvider).play(HapticMoment.taskChecked);
/// ref.read(hapticsProvider).play(HapticMoment.moodMove, step: index);
/// final breath = ref.read(hapticsProvider).hold(HapticMoment.thawBreath);
/// ...
/// breath.cancel(); // fades out over 150 ms
/// ```
///
/// **Touch and picture land together** (principle 5): call this in the same
/// place the visual change is made — the `setState`, the controller method —
/// not after an await that follows it.
abstract interface class HapticsService {
  /// Play [moment]. [step], [count] and [mode] are read only by the moments
  /// that document them. [landed] marks a wheel's final, full-strength tick.
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false});

  /// Start a pattern that lasts as long as something on screen does — the
  /// thaw breath, a hold-to-confirm ratchet — and return a handle to end it.
  HapticHold hold(HapticMoment moment);

  /// Watch whether the phone lies face down, so a completed session's bloom
  /// can hum instead of rattling on a desk. On while the timer is on screen.
  void watchFaceDown({required bool on});
}

/// A running hold. Ending it twice is harmless.
abstract interface class HapticHold {
  /// Let it go: fade out from wherever it is over [fade] (§4: "The breath
  /// fades out over 150 ms"; a ratchet lifted early "ends with a soft fall").
  void cancel({Duration fade = const Duration(milliseconds: 150)});

  /// It ran to its end on screen; stop it without a fade.
  void finish();
}

class _NoHold implements HapticHold {
  const _NoHold();

  @override
  void cancel({Duration fade = const Duration(milliseconds: 150)}) {}

  @override
  void finish() {}
}

/// Silence: the web (iOS Safari has no vibration), widget tests, and a
/// caller holding this cannot buzz by accident.
class NoopHapticsService implements HapticsService {
  const NoopHapticsService();

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) {}

  @override
  HapticHold hold(HapticMoment moment) => const _NoHold();

  @override
  void watchFaceDown({required bool on}) {}
}

/// The real thing. Every play goes through a [HapticGovernor].
class RealHapticsService implements HapticsService {
  RealHapticsService({
    required HapticSetting Function() setting,
    required bool Function() focusRunning,
    required bool Function() reducedMotion,
    bool Function()? foreground,
    HapticDriver? driver,
    HapticGovernor? governor,
    DateTime Function()? clock,
  })  : _setting = setting,
        _focusRunning = focusRunning,
        _reducedMotion = reducedMotion,
        _foreground = foreground ?? appInForeground,
        _driverOverride = driver,
        _clock = clock ?? DateTime.now {
    _governor = governor ??
        HapticGovernor(
          play: (h) => _driver.play(h),
          stop: (id) => _driver.stop(id),
          clock: _clock,
        );
    _refreshDeviceState();
  }

  final HapticSetting Function() _setting;
  final bool Function() _focusRunning;
  final bool Function() _reducedMotion;
  final bool Function() _foreground;
  final HapticDriver? _driverOverride;
  final DateTime Function() _clock;
  late final HapticGovernor _governor;

  HapticDriver get _driver => _driverOverride ?? hapticDriver;

  HapticDeviceState _device = const HapticDeviceState();
  DateTime? _deviceCheckedAt;

  /// Low Power Mode and heat change slowly; asking every 30 s at most, and
  /// never waiting for the answer, keeps every haptic instant.
  void _refreshDeviceState() {
    final now = _clock();
    final last = _deviceCheckedAt;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) return;
    _deviceCheckedAt = now;
    unawaited(_driver.deviceState().then((s) => _device = s));
  }

  /// Low Power Mode, a hot phone, or the OS reduce-motion switch: each drops
  /// Full to Essential. Reduce-motion is very often a statement about sensory
  /// load, and the app setting may be stricter than the OS, never looser.
  bool get _constrained {
    _refreshDeviceState();
    return _device.constrained || _reducedMotion();
  }

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) {
    // We never vibrate from inside another app: a session completing or a
    // thaw ending with Aqademiq in the background is the notification's job.
    if (!_foreground()) return;
    final spec = specFor(moment, step: step, count: count, mode: mode);
    _governor.submit(
      moment,
      spec,
      setting: _setting(),
      focusRunning: _focusRunning(),
      constrained: _constrained,
      landed: landed,
      faceDownAlt: moment == HapticMoment.sessionComplete ? spec.deskSafe() : null,
    );
  }

  @override
  HapticHold hold(HapticMoment moment) {
    if (!_foreground()) return const _NoHold();
    final spec = specFor(moment);
    final admitted = _governor.admitHold(
      moment,
      spec,
      setting: _setting(),
      focusRunning: _focusRunning(),
      constrained: _constrained,
    );
    if (admitted == null) return const _NoHold();
    _driver.play(admitted);
    return _RunningHold(_driver, admitted, _clock(), _clock);
  }

  @override
  void watchFaceDown({required bool on}) => _driver.watchFaceDown(on: on);
}

class _RunningHold implements HapticHold {
  _RunningHold(this._driver, this._haptic, this._startedAt, this._clock);

  final HapticDriver _driver;
  final AdmittedHaptic _haptic;
  final DateTime _startedAt;
  final DateTime Function() _clock;
  bool _done = false;

  @override
  void cancel({Duration fade = const Duration(milliseconds: 150)}) {
    if (_done) return;
    _done = true;
    _driver.stop(_haptic.id, fade: fade, level: levelAt(_haptic.spec, _clock().difference(_startedAt)));
  }

  @override
  void finish() {
    if (_done) return;
    _done = true;
    _driver.stop(_haptic.id);
  }
}

/// How strong [spec]'s continuous layer is [elapsed] into it — where a fade
/// starts from when a hold is let go.
@visibleForTesting
double levelAt(HapticSpec spec, Duration elapsed) {
  var level = 0.0;
  for (final e in spec.ios) {
    if (e is IosCurve && elapsed >= e.at && elapsed <= e.end) {
      final t = (elapsed - e.at).inMicroseconds / e.duration.inMicroseconds;
      final v = e.intensityAt(t);
      if (v > level) level = v;
    }
  }
  return level;
}

/// Whether Aqademiq is the app on screen. Unknown (no binding yet, a unit
/// test) counts as yes.
bool appInForeground() {
  try {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  } on Object {
    return true;
  }
}

/// The OS reduce-motion flag, read from the platform dispatcher because most
/// moments fire from controllers with no `BuildContext`.
bool osReducedMotion() => PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

/// Picks the implementation, exactly like `tasksRepositoryProvider` does.
final hapticsProvider = Provider<HapticsService>((ref) {
  if (kIsWeb) return const NoopHapticsService();
  return RealHapticsService(
    setting: () => ref.read(hapticSettingProvider),
    // Read, never watch: sampled at the instant a moment is offered.
    focusRunning: () => ref.read(focusControllerProvider).status == FocusStatus.running,
    reducedMotion: osReducedMotion,
  );
});
