/// Turning the app's own data into the glanceable half of the shared state.
///
/// Pure on purpose, and tested as such: a widget shows this to a student who
/// has not opened the app, so getting "next" wrong is not a cosmetic bug — it
/// is the app confidently telling someone the wrong thing to do next.
library;

import '../../core/utils/date_format.dart';
import '../../data/models/mood_log.dart';
import '../../data/models/tag.dart';
import '../../data/models/task.dart';
import 'ambient_state.dart';

/// The one task a student is meant to be doing.
///
/// One, never a list. A list makes them choose again, and choosing again is the
/// decision that stalls them in the first place.
///
/// "Next" means the earliest unfinished thing left today: timed tasks in clock
/// order first, then untimed ones, which is the order the Plan screen already
/// shows them in. A task whose time has passed but which is not done is still
/// next — it has not stopped needing doing just because it is late.
Task? nextTaskFrom(List<Task> tasks, {DateTime? now}) {
  final pending = tasks.where((t) => !t.done).toList();
  if (pending.isEmpty) return null;

  final timed = pending.where((t) => t.startTime != null).toList()
    ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
  if (timed.isEmpty) return pending.first;

  final at = now ?? DateTime.now();
  // Prefer something still ahead; fall back to the earliest overdue one rather
  // than skipping to tomorrow and pretending the day is over.
  final upcoming = timed.where((t) => !t.startTime!.isBefore(at));
  return upcoming.isNotEmpty ? upcoming.first : timed.first;
}

/// Seven flags, Monday first: did the student show up that day.
///
/// Read from the check-in logs the app already keeps, because that row is
/// exactly what the design lifts onto the home screen. A day they logged wears
/// Ada's face; a day they did not is an empty outline — never a puddle, since
/// absence is not depletion, and never a decaying streak, since the widget is
/// the surface with the least consent.
List<bool> weekDaysFrom(List<MoodLog> logs, {DateTime? now}) {
  final monday = AppDate.mondayOf(now ?? DateTime.now());
  final logged = <String>{
    for (final log in logs) _key(log.date),
  };
  return [
    for (var i = 0; i < 7; i++)
      logged.contains(_key(monday.add(Duration(days: i)))),
  ];
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Build the glanceable payload the widgets read.
///
/// [session] is threaded through untouched: publishing what the widgets show
/// must never disturb a running session, and the two are written together.
AmbientState glanceState({
  required List<Task> tasks,
  required List<MoodLog> weekLogs,
  Map<String, Tag> tagsById = const {},
  int todayFocusMin = 0,
  AmbientSession? session,
  DateTime? now,
}) {
  final next = nextTaskFrom(tasks, now: now);
  final tag = next == null ? null : tagsById[next.tagId];
  return AmbientState(
    session: session,
    nextTaskTitle: next?.title,
    nextTaskTime:
        next?.startTime == null ? null : AppDate.time12h(next!.startTime!),
    nextTaskSubject: tag?.label,
    nextTaskTint: tag?.color,
    weekDays: weekDaysFrom(weekLogs, now: now),
    todayFocusMin: todayFocusMin,
  );
}
