import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/mood_repository.dart';
import '../../../services/haptics/haptic_settings_service.dart';
import '../../../services/haptics/haptics_service.dart';

/// Watches the day streak and fires the Tier 1 haptic at the **crossing**.
///
/// The guide notes there is no controller for this today, and there wasn't:
/// `streakProvider` is a derived read, recomputed from the mood week whenever a
/// log lands. This is that controller.
///
/// Spec §4.5 is the whole difficulty — "a streak fires the instant it is
/// *crossed*, never each time it is displayed", and "never greet someone with a
/// buzz on launch". Two guards cover both:
///
///  * a **persisted watermark** (`HapticSettingsService.streakMark`), the
///    highest streak already accounted for. A milestone is celebrated once in
///    the life of the install rather than once per recompute. The watermark
///    falls as well as rises, so a broken streak re-arms the ladder and
///    climbing back to seven days is a real crossing again.
///  * a **session baseline** — the first value seen after launch is recorded in
///    silence. Without it, opening the app on a device that already has a
///    30-day streak would buzz on the splash screen.
///
/// Kept alive from `app.dart`, not from the Stats screen. The crossing happens
/// when a mood is logged — on Plan, on the Mood screens, in the Stats day
/// editor — and hanging it off the screen that merely *displays* the number is
/// precisely the mistake §4.5 names. The trade is that the mood week is now
/// read once at launch; under mocks that is a fixture, and live it is the same
/// request Stats already makes.
final streakMilestoneProvider =
    NotifierProvider<StreakMilestoneController, int>(
  StreakMilestoneController.new,
);

class StreakMilestoneController extends Notifier<int> {
  /// The ladder. Chosen here rather than specified: spec §3 says a milestone
  /// fires at the crossing but never says which numbers are milestones. Sparse
  /// on purpose — a Tier 1 event that fires every day is not a Tier 1 event.
  static const List<int> milestones = [3, 7, 14, 30, 50, 100, 200, 365];

  bool _seenOnce = false;

  @override
  int build() {
    ref.listen<AsyncValue<int>>(streakProvider, (_, next) {
      final streak = next.value;
      if (streak != null) _onStreak(streak);
    });
    return HapticSettingsService.instance.streakMark;
  }

  void _onStreak(int streak) {
    final mark = state;
    if (streak == mark && _seenOnce) return;

    final baseline = !_seenOnce;
    _seenOnce = true;

    final crossed = !baseline &&
        streak > mark &&
        milestones.any((m) => m > mark && m <= streak);

    if (streak != mark) {
      state = streak;
      unawaited(HapticSettingsService.instance.setStreakMark(streak));
    }

    if (crossed) ref.read(hapticsProvider).streakMilestone();
  }
}
