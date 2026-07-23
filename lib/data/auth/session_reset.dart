import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../features/onboarding/providers/onboarding_controller.dart';
import '../../features/plan/providers/plan_providers.dart';
import '../../features/settings/providers/profile_controller.dart';
import '../repositories/ada_repository.dart';
import '../repositories/mood_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/referral_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/subjects_repository.dart';
import '../repositories/tags_repository.dart';
import 'auth_repository.dart';

/// Wipes user-scoped in-memory state whenever the signed-in identity changes —
/// a sign-out, or switching to a different account without an app restart.
///
/// Notifier-backed caches (the Settings profile, the onboarding draft) otherwise
/// survive the switch, so a freshly created account would show the *previous*
/// user's name/details and their half-filled onboarding draft. Token refreshes
/// keep the same user id and are ignored. Kept alive at the app root. No-op
/// under `Env.useMocks` (the demo profile is intentionally fixed there).
final sessionResetProvider = Provider<void>((ref) {
  if (Env.useMocks) return;

  String? lastUserId;
  ref.listen(authStateProvider, (_, next) {
    final id = next.value?.id;
    if (id == lastUserId) return; // same user (e.g. token refresh) — no reset
    lastUserId = id;
    ref
      ..invalidate(profileControllerProvider)
      ..invalidate(onboardingProvider)
      ..invalidate(adaConversationsProvider)
      ..invalidate(referralCodeProvider)
      ..invalidate(notificationPrefsProvider)
      ..invalidate(emailPrefsProvider)
      ..invalidate(dayTasksProvider)
      ..invalidate(weeklyCompletedProvider)
      ..invalidate(subjectsProvider)
      ..invalidate(semestersProvider)
      ..invalidate(tagsProvider)
      ..invalidate(moodWeekProvider)
      ..invalidate(statsProvider);
  }, fireImmediately: true);
});
