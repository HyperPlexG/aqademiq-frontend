import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../features/plan/providers/plan_providers.dart';
import '../../services/reminder_scheduler.dart';
import '../auth/auth_repository.dart';
import '../repositories/mood_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/subjects_repository.dart';
import '../repositories/tags_repository.dart';
import 'realtime_repository.dart';

/// Keeps live data fresh via the contract's "signal → refetch" pattern (§8.3):
/// connect the `/me/revisions` socket while authenticated, and on each
/// `revision` bump invalidate the read providers so they re-pull.
///
/// Kept alive by being watched at the app root. No-op under `Env.useMocks`.
final revisionSyncProvider = Provider<void>((ref) {
  if (Env.useMocks) return;

  ref
    // Open/close the socket as auth state changes.
    ..listen(authStateProvider, (_, next) {
      final repo = ref.read(realtimeRepositoryProvider);
      if (next.value != null) {
        repo.connect();
      } else {
        repo.disconnect();
      }
    }, fireImmediately: true)
    // On a revision bump, refetch the user-scoped read models.
    ..listen(revisionEventsProvider, (_, next) {
      if (next.value == null) return;
      ref
        ..invalidate(dayTasksProvider)
        ..invalidate(weeklyCompletedProvider)
        ..invalidate(subjectsProvider)
        ..invalidate(semestersProvider)
        ..invalidate(tagsProvider)
        ..invalidate(moodWeekProvider)
        ..invalidate(statsProvider);
      // Tasks Ada scheduled server-side arrive as a revision bump and nothing
      // else, so this is the only trigger that catches them.
      unawaited(ref.read(reminderSchedulerProvider).reconcile());
    });
});
