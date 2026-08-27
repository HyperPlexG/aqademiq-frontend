import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../services/reminder_scheduler.dart';

/// The day currently shown on the Plan timeline (defaults to the demo "today").
final selectedDateProvider =
    NotifierProvider<SelectedDateController, DateTime>(SelectedDateController.new);

class SelectedDateController extends Notifier<DateTime> {
  @override
  DateTime build() => AppDate.today();

  void select(DateTime date) => state = DateTime(date.year, date.month, date.day);

  void goToToday() => state = AppDate.today();
}

/// Coarse bucket a task belongs to — derived from its [Task.startTime] when set,
/// otherwise its [Task.dayPart]. Single source of truth for grouping so the
/// timeline and list views never disagree (PLAN-1).
DayPart taskBucket(Task t) {
  final start = t.startTime;
  if (start != null) {
    if (start.hour < 12) return DayPart.morning;
    if (start.hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }
  return t.dayPart ?? DayPart.anytime;
}

/// Tasks for the selected day, as `AsyncValue<List<Task>>` (loading/error/data
/// for free). Re-runs whenever [selectedDateProvider] changes.
final dayTasksProvider =
    AsyncNotifierProvider<DayTasksController, List<Task>>(DayTasksController.new);

class DayTasksController extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() {
    final date = ref.watch(selectedDateProvider);
    return ref.watch(tasksRepositoryProvider).tasksForDay(date);
  }

  /// Optimistically flip a task's done state, rolling back on failure
  /// (README §7: "optimistic updates for toggles").
  ///
  /// The haptic confirms the **outcome**, not the tap (spec §2.1). These three
  /// mutations are optimistic with rollback, and guide §4.2 gives two coherent
  /// choices for that: fire after the repository succeeds, or fire optimistically
  /// and follow a rollback with `saveFailed`. This file picks the first —
  /// consistently, in all three — because it is the one that cannot teach the
  /// hand a lie. The rollback still speaks, in Tier 4.
  Future<void> toggleDone(Task task) async {
    final previous = state.value ?? const <Task>[];
    final next = task.copyWith(done: !task.done);
    state = AsyncData([
      for (final t in previous) if (t.id == task.id) next else t,
    ]);
    try {
      await ref.read(tasksRepositoryProvider).update(next);
      // Only a completion is an earned moment. Un-ticking a task is a correction,
      // and rewarding it would make the signature haptic of the product mean
      // "you touched a checkbox".
      if (next.done) ref.read(hapticsProvider).taskCompleted();
      ref.invalidate(weeklyCompletedProvider);
      _rescheduleReminders();
    } on Object catch (_) {
      state = AsyncData(previous);
      ref.read(hapticsProvider).saveFailed();
    }
  }

  /// Optimistically tick a micro-step off, rolling back on failure.
  ///
  /// The whole point of a breakdown is working through it, so this has to feel
  /// instant — the step was previously not tappable at all, and a round trip
  /// before the tick appears would make it feel broken in a different way.
  Future<void> toggleStep(Task task, Subtask step) async {
    final previous = state.value ?? const <Task>[];
    final done = !step.done;
    final next = task.copyWith(
      subtasks: [
        for (final s in task.subtasks)
          if (s.id == step.id) s.copyWith(done: done) else s,
      ],
    );
    state = AsyncData([
      for (final t in previous) if (t.id == task.id) next else t,
    ]);
    try {
      await ref.read(tasksRepositoryProvider).setStepDone(task.id, step.id, done: done);
    } on Object catch (_) {
      state = AsyncData(previous);
    }
  }

  /// Move a task to another day — it leaves the current day's list.
  Future<void> move(Task task, DateTime newDate) async {
    final previous = state.value ?? const <Task>[];
    state = AsyncData([for (final t in previous) if (t.id != task.id) t]);
    try {
      await ref.read(tasksRepositoryProvider).move(task, newDate);
      // Light single. Must never feel like a penalty — pushing a task is a
      // legitimate way to use the app, not a failure to finish it.
      ref.read(hapticsProvider).taskRescheduled();
      ref.invalidate(weeklyCompletedProvider);
      _rescheduleReminders();
    } on Object catch (_) {
      state = AsyncData(previous);
      ref.read(hapticsProvider).saveFailed();
    }
  }

  /// Optimistically remove a task (swipe-to-delete / overflow Delete).
  Future<void> delete(Task task) async {
    final previous = state.value ?? const [];
    state = AsyncData([for (final t in previous) if (t.id != task.id) t]);
    try {
      await ref.read(tasksRepositoryProvider).delete(task.id);
      ref.read(hapticsProvider).destructiveConfirmed();
      ref.invalidate(weeklyCompletedProvider);
      _rescheduleReminders();
    } on Object catch (_) {
      state = AsyncData(previous);
      ref.read(hapticsProvider).saveFailed();
    }
  }

  /// Completing, moving or deleting a task changes what should be pending on
  /// the device. Forced (not debounced) so the schedule matches the list the
  /// user is looking at, and fire-and-forget so it never delays the UI.
  void _rescheduleReminders() =>
      unawaited(ref.read(reminderSchedulerProvider).reconcile(force: true));
}

/// Completed-task count for the selected week — drives the Stats "COMPLETED"
/// tile so ticking a task updates it (STA-4). Recomputed on week change and
/// invalidated by the task mutations above.
final weeklyCompletedProvider = FutureProvider<int>((ref) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(tasksRepositoryProvider).completedThisWeek(date);
});
