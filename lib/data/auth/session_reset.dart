import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../features/feedback/providers/feedback_providers.dart';
import '../../features/focus/providers/linked_task_provider.dart';
import '../../features/freeze/presentation/freeze_apps.dart';
import '../../features/freeze/providers/freeze_controller.dart';
import '../../features/import/providers/import_session.dart';
import '../../features/onboarding/providers/onboarding_controller.dart';
import '../../features/plan/providers/plan_providers.dart';
import '../../features/plan/providers/plan_ui_providers.dart';
import '../../features/settings/providers/profile_controller.dart';
import '../../services/ambient/ambient_service.dart';
import '../repositories/ada_memory_repository.dart';
import '../repositories/ada_repository.dart';
import '../repositories/focus_repository.dart';
import '../repositories/mood_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/referral_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/subjects_repository.dart';
import '../repositories/tags_repository.dart';
import '../repositories/weekly_report_repository.dart';
import 'account_owner_store.dart';
import 'auth_repository.dart';

/// Wipes user-scoped state whenever the signed-in identity changes — a
/// sign-out, or switching to a different account without an app restart.
///
/// Two kinds of state, two rules:
///
/// * **Server caches** (profile, tasks, moods, Ada's conversations …) are
///   invalidated on every change of identity, so the next account refetches
///   its own. Notifier-backed ones otherwise survive the switch — a fresh
///   account would show the *previous* user's name and half-filled onboarding
///   draft. Token refreshes keep the same user id and are ignored. Skipped
///   under `Env.useMocks` (the demo profile is intentionally fixed there).
/// * **The phone's own state** — App freeze, the focus setup and its linked
///   task, the widgets and lock screen, half-finished drafts — is never
///   refetched, so it is forgotten outright ([forgetLocalAccountState]) when
///   an account goes: on signing out, and when someone other than its owner
///   ([AccountOwnerStore]) arrives. Not on the first sign-in of a run: that is
///   the same student coming back, and their frosts stay. Runs under mocks
///   too — this state is real there.
///
/// Kept alive at the app root.
final sessionResetProvider = Provider<void>((ref) {
  String? lastUserId;
  var first = true;
  ref.listen(authStateProvider, (_, next) {
    final initial = first;
    first = false;
    // Still finding out: not an identity, signed in or out.
    if (next.isLoading && !next.hasValue) return;
    final id = next.value?.id;
    if (id == lastUserId) return; // same user (e.g. token refresh) — no reset
    final previous = lastUserId;
    lastUserId = id;

    final owners = AccountOwnerStore.instance;
    final owner = owners.owner;
    // Signed out in this run, switched account in this run, or the phone's
    // state belongs to an account that is not the one arriving now.
    final forget =
        previous != null || (id != null && owner != null && owner != id);
    if (id != null) {
      unawaited(owners.setOwner(id));
    } else if (forget) {
      unawaited(owners.setOwner(null));
    }

    void reset() {
      if (forget) forgetLocalAccountState(ref);
      if (!Env.useMocks) _invalidateServerCaches(ref);
    }

    // The first answer can arrive while this provider is still being built,
    // and a provider may not change others then.
    if (initial) {
      scheduleMicrotask(reset);
    } else {
      reset();
    }
  }, fireImmediately: true);
});

/// Everything this phone keeps for the signed-in account that a server fetch
/// will not replace. Called on sign-out and on a change of account.
///
/// * The focus session and its linked task — a running session stands down,
///   so the Live Activity, the Island and the Android card go with it.
/// * App freeze: frosts, groups, The usual, a running Freeze now, thaws and
///   stand-down, and the iOS picks behind them. The native side is handed the
///   empty policy, so no app is left frozen with nobody signed in to see why
///   ([FreezeController.forgetAll]).
/// * The widgets, lock screen and watch: the next task, the mood week and
///   today's focus minutes ([AmbientService.forgetAccount]).
/// * In-memory drafts: the open Ada chat, a Quick-add draft, an import being
///   reviewed, the expanded task, the chosen semester.
///
/// Per-device settings stay: theme, sounds, haptics, Prism defaults, the
/// weekly report switch, Ice Breakers watched, the subjects sort.
void forgetLocalAccountState(Ref ref) {
  // The session first: the surfaces stand down from it before they are blanked.
  ref.read(focusControllerProvider.notifier).reset();
  ref.read(linkedTaskProvider.notifier).clear();
  ref.read(freezeControllerProvider.notifier).forgetAll();
  ref
    ..invalidate(fzSelectionTokensProvider)
    ..invalidate(adaChatProvider)
    ..invalidate(taskDraftProvider)
    ..invalidate(importSessionProvider)
    ..invalidate(expandedTaskProvider)
    ..invalidate(selectedSemesterProvider);
  ref.read(ambientServiceProvider).forgetAccount();
}

void _invalidateServerCaches(Ref ref) {
  ref
    ..invalidate(profileControllerProvider)
    ..invalidate(onboardingProvider)
    ..invalidate(adaConversationsProvider)
    ..invalidate(adaMemoriesProvider)
    ..invalidate(referralSummaryProvider)
    ..invalidate(referralCodeProvider)
    ..invalidate(notificationPrefsProvider)
    ..invalidate(emailPrefsProvider)
    ..invalidate(dayTasksProvider)
    ..invalidate(weeklyCompletedProvider)
    ..invalidate(subjectsProvider)
    ..invalidate(semestersProvider)
    ..invalidate(tagsProvider)
    ..invalidate(moodWeekProvider)
    ..invalidate(statsProvider)
    ..invalidate(weeklyReportProvider)
    ..invalidate(feedbackPostsProvider)
    ..invalidate(feedbackSubscriptionProvider);
}
