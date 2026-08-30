import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/repositories/focus_repository.dart';
import '../../features/settings/providers/haptic_settings_provider.dart';
import 'haptic_governor.dart';
import 'haptic_patterns.dart';

/// What the rest of the app talks to — spec §6.1, guide §1.1.
///
/// An `abstract interface class` with two implementations, mirroring the
/// `MockXxxSource` / `ApiXxxSource` pairing the repo uses everywhere
/// (README §7, seam 3) and provided by [hapticsProvider], exactly as
/// `tasksRepositoryProvider` picks its source.
///
/// Every method names a **state change**, never a feel. That is the admission
/// rule (§8.1) encoded in the type: you cannot call this API without saying
/// which of the 22 sanctioned transitions just happened. If a proposed haptic
/// has no method here, the answer is a spec review, not a `HapticFeedback` call.
abstract interface class HapticsService {
  // ── Tier 1 — earned moments ────────────────────────────────────────────
  void taskCompleted();
  void focusCompleted();
  void streakMilestone();
  void guestUpgraded();
  void onboardingFinished();

  // ── Tier 2 — state confirmations ───────────────────────────────────────
  void taskCreated();
  void taskRescheduled();
  void focusStarted();
  void sessionFrozen();
  void sessionResumed();
  void sessionEndedEarly();
  void moodLogged();
  void subjectCreated();
  void suggestionPosted();
  void voteCast();

  // ── Tier 3 — selection detents ─────────────────────────────────────────
  /// [index] is the 0–4 melt position, so the tick can follow the ramp (§5.1).
  void moodRampStep(int index);
  void wheelItem();
  void sliderStop();
  void segmentChange();

  /// The task-card long-press (spec Finding 04). Fires as the gesture is
  /// recognised, not after the sheet opens — the tick *is* the confirmation
  /// that the long-press worked.
  void longPressTick();

  // ── Tier 4 — warnings ──────────────────────────────────────────────────
  void destructiveConfirmed();
  void saveFailed();
  void guestWallHit();
}

/// The 22 semantic names, funnelled to a single [emit] so neither
/// implementation repeats them.
abstract class _HapticsBase implements HapticsService {
  const _HapticsBase();

  void emit(HapticEvent event, {int? rampStep});

  @override
  void taskCompleted() => emit(HapticEvent.taskCompleted);

  @override
  void focusCompleted() => emit(HapticEvent.focusCompleted);

  @override
  void streakMilestone() => emit(HapticEvent.streakMilestone);

  @override
  void guestUpgraded() => emit(HapticEvent.guestUpgraded);

  @override
  void onboardingFinished() => emit(HapticEvent.onboardingFinished);

  @override
  void taskCreated() => emit(HapticEvent.taskCreated);

  @override
  void taskRescheduled() => emit(HapticEvent.taskRescheduled);

  @override
  void focusStarted() => emit(HapticEvent.focusStarted);

  @override
  void sessionFrozen() => emit(HapticEvent.sessionFrozen);

  @override
  void sessionResumed() => emit(HapticEvent.sessionResumed);

  @override
  void sessionEndedEarly() => emit(HapticEvent.sessionEndedEarly);

  @override
  void moodLogged() => emit(HapticEvent.moodLogged);

  @override
  void subjectCreated() => emit(HapticEvent.subjectCreated);

  @override
  void suggestionPosted() => emit(HapticEvent.suggestionPosted);

  @override
  void voteCast() => emit(HapticEvent.voteCast);

  @override
  void moodRampStep(int index) =>
      emit(HapticEvent.moodRampStep, rampStep: index);

  @override
  void wheelItem() => emit(HapticEvent.wheelItem);

  @override
  void sliderStop() => emit(HapticEvent.sliderStop);

  @override
  void segmentChange() => emit(HapticEvent.segmentChange);

  @override
  void longPressTick() => emit(HapticEvent.longPressTick);

  @override
  void destructiveConfirmed() => emit(HapticEvent.destructiveConfirmed);

  @override
  void saveFailed() => emit(HapticEvent.saveFailed);

  @override
  void guestWallHit() => emit(HapticEvent.guestWallHit);
}

/// Silence. Covers three cases at once (guide §1.1):
///
///  * **Web** — iOS Safari has no Vibration API. Ship silence, not a degraded
///    approximation. The app is run in Chrome for testing, so this path is
///    exercised constantly.
///  * **Tests** — widget tests must never depend on a platform channel.
///  * **Setting = Off** — belt and braces; the governor already drops
///    everything, but a caller holding this instance cannot buzz by accident.
class NoopHapticsService extends _HapticsBase {
  const NoopHapticsService();

  @override
  void emit(HapticEvent event, {int? rampStep}) {}
}

/// The real thing. Every call goes through a [HapticGovernor]; nothing reaches
/// [playHapticEvent] without passing all five rules.
///
/// The setting, focus status and reduce-motion flag are supplied as closures
/// rather than read here, so the governor stays a plain unit-testable class and
/// this class stays a thin adapter over it (guide §1.3).
class RealHapticsService extends _HapticsBase {
  RealHapticsService({
    required HapticSetting Function() setting,
    required bool Function() focusRunning,
    required bool Function() reducedMotion,
    HapticGovernor? governor,
  })  : _setting = setting,
        _focusRunning = focusRunning,
        _reducedMotion = reducedMotion,
        _governor = governor ??
            HapticGovernor(
              play: (event, rampStep) =>
                  unawaited(playHapticEvent(event, rampStep: rampStep)),
            );

  final HapticSetting Function() _setting;
  final bool Function() _focusRunning;
  final bool Function() _reducedMotion;
  final HapticGovernor _governor;

  @override
  void emit(HapticEvent event, {int? rampStep}) => _governor.submit(
        event,
        setting: _setting(),
        focusRunning: _focusRunning(),
        reducedMotion: _reducedMotion(),
        rampStep: rampStep,
      );
}

/// The OS "reduce motion" flag.
///
/// This is the same signal `MediaQuery.of(context).disableAnimations` exposes,
/// read one layer down — which matters because most of the 22 events fire from
/// controllers that have no `BuildContext`. It is also the honest source for
/// spec §6.5's "must sit **under** the OS accessibility setting": the platform
/// dispatcher is the OS's answer, whereas a `MediaQuery` can be overridden by
/// any widget above the reader.
bool osReducedMotion() =>
    PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

/// Picks the implementation, exactly like `tasksRepositoryProvider` does.
final hapticsProvider = Provider<HapticsService>((ref) {
  if (kIsWeb) return const NoopHapticsService();
  return RealHapticsService(
    setting: () => ref.read(hapticSettingProvider),
    // Read, never watch: this is sampled at the instant an event is offered, so
    // the governor sees the status as it is *now* rather than as it was when
    // the service was built.
    focusRunning: () =>
        ref.read(focusControllerProvider).status == FocusStatus.running,
    reducedMotion: osReducedMotion,
  );
});
