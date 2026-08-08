import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/env/env.dart';
import '../core/router/app_router.dart';
import '../data/auth/auth_repository.dart';
import '../data/models/task.dart';
import '../data/models/user_settings.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/tasks_repository.dart';
import '../features/plan/providers/plan_providers.dart';
import 'local_notifications.dart';

/// Client-side reminders.
///
/// The backend has a server-push path (`pg_cron` → `/cron/notifications` →
/// `runReminderSweep()` → FCM) but it has not been delivering reliably, and it
/// only ever implemented one of the seven channels the Notifications settings
/// screen offers. So the device schedules its own reminders from the task list
/// it already has, needing no server, no FCM credentials, and no account —
/// local notifications work in Guest Mode too.
///
/// The model is **reconcile, not fire-and-forget**. Scheduling only at
/// task-create drifts within minutes: tasks get edited on another device,
/// completed, deleted, or created by Ada server-side. Instead every trigger
/// (sign-in, app resume, a task mutation, a revision bump, a settings change)
/// re-derives the whole desired schedule from current state and diffs it
/// against what is actually pending. That also sidesteps the two bugs that make
/// the server sweep miss: its `notification_deliveries` dedup key is per task
/// and never cleared (so a rescheduled or repeating task is silent forever),
/// and virtual recurring occurrences have no row to carry a `reminder_at`.
///
/// See [Env.localReminders] for the kill switch.

/// The reminder kinds the client schedules. The keys match the backend's
/// `channel_key` vocabulary so a payload reads the same from either source.
enum ReminderChannel {
  beforeTask('before_task'),
  taskStart('task_start'),
  taskHalf('task_half'),
  taskEnd('task_end'),
  morning('morning'),
  review('review'),
  weeklyReview('weekly_review');

  const ReminderChannel(this.key);

  final String key;
}

/// How far before a scheduled task's start the "before task" reminder fires.
/// Mirrors `REMINDER_LEAD_MS` in the backend's `tasks.service.ts` so the two
/// paths agree on what "before task" means.
const reminderLead = Duration(minutes: 10);

/// How far ahead task reminders are scheduled. Rolls forward on every reconcile,
/// so the window is refilled long before it empties.
const schedulingHorizon = Duration(days: 7);

/// Ceiling on pending task reminders.
///
/// iOS keeps at most 64 pending local notifications per app and silently drops
/// the rest, so the budget is spent soonest-first and kept under the limit with
/// room for the three repeating check-ins plus headroom.
const maxTaskReminders = 56;

/// The three check-ins repeat, so they hold fixed low ids; task reminders hash
/// into the range above [_taskIdBase].
const _checkInIds = <ReminderChannel, int>{
  ReminderChannel.morning: 1,
  ReminderChannel.review: 2,
  ReminderChannel.weeklyReview: 3,
};
const _taskIdBase = 1000;

/// Java `int` ceiling — Android notification ids must fit in one.
const _idCeiling = 2147483647;

/// The weekday the weekly review lands on. Sunday evening is when planning the
/// coming week is actually useful; the backend never implemented this channel,
/// so the choice is ours.
const int _weeklyReviewWeekday = DateTime.sunday;

/// One notification the scheduler intends to have pending.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.channel,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.repeat,
  });

  final int id;
  final ReminderChannel channel;

  /// Local wall-clock time to fire at. For a [repeat]ing reminder this is the
  /// next occurrence.
  final DateTime at;
  final String title;
  final String body;

  /// JSON read back by [ReminderScheduler]'s tap handler to open the right day.
  final String payload;

  /// Non-null for the repeating check-ins.
  final DateTimeComponents? repeat;
}

/// Stable id for a task reminder.
///
/// Must be deterministic across reconciles: scheduling an id that is already
/// pending replaces it, so a task whose time didn't change is left alone rather
/// than cancelled and re-created. FNV-1a keeps it cheap; a collision would mean
/// one reminder displacing another, which at a 56-notification budget is not
/// worth a lookup table to avoid.
int reminderIdFor(String occurrenceId, ReminderChannel channel) {
  var hash = 0x811c9dc5;
  for (final unit in '$occurrenceId|${channel.key}'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return _taskIdBase + hash % (_idCeiling - _taskIdBase);
}

String _p2(int n) => n.toString().padLeft(2, '0');

String _ymd(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)}';

String _payload(ReminderChannel channel, {String? taskId, DateTime? date}) =>
    jsonEncode(<String, String>{
      'channel': channel.key,
      'task': ?taskId,
      if (date != null) 'date': _ymd(date),
    });

/// Derive the task-relative reminders for [tasks], honouring the user's channel
/// toggles. Pure — the scheduler's testable core.
///
/// Only timed tasks are covered: a date-only task has no moment to fire at, so
/// those users are served by the daily check-ins instead. Reminders already in
/// the past, or beyond [horizon], are dropped; the rest are ordered by fire time
/// and truncated to [limit].
@visibleForTesting
List<PlannedReminder> planTaskReminders({
  required List<Task> tasks,
  required NotificationChannels channels,
  required DateTime now,
  Duration horizon = schedulingHorizon,
  int limit = maxTaskReminders,
}) {
  final until = now.add(horizon);
  final planned = <PlannedReminder>[];

  for (final task in tasks) {
    final start = task.startTime;
    if (task.done || start == null) continue;
    final duration = Duration(minutes: task.durationMin ?? 0);

    void add(ReminderChannel channel, DateTime at, String title) {
      if (!at.isAfter(now) || at.isAfter(until)) return;
      planned.add(
        PlannedReminder(
          id: reminderIdFor(task.id, channel),
          channel: channel,
          at: at,
          title: title,
          body: task.title,
          payload: _payload(channel, taskId: task.id, date: task.date),
        ),
      );
    }

    if (channels.beforeTask) {
      add(
        ReminderChannel.beforeTask,
        start.subtract(reminderLead),
        'Starting in ${reminderLead.inMinutes} minutes',
      );
    }
    if (channels.taskStart) {
      add(ReminderChannel.taskStart, start, 'Starting now');
    }
    // Halfway and finished only mean something for a task with a real duration.
    if (channels.taskHalf && duration.inMinutes >= 2) {
      add(ReminderChannel.taskHalf, start.add(duration ~/ 2), 'Halfway through');
    }
    if (channels.taskEnd && duration.inMinutes >= 1) {
      add(ReminderChannel.taskEnd, start.add(duration), "Time's up");
    }
  }

  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned.length <= limit
      ? planned
      : planned.sublist(0, limit);
}

/// Derive the repeating morning / evening / weekly check-ins from [prefs].
///
/// These repeat via `matchDateTimeComponents` rather than being materialised as
/// one-shots, so all three together cost three slots of the iOS budget instead
/// of ~21 a week.
@visibleForTesting
List<PlannedReminder> planCheckIns(
  NotificationPrefs prefs, {
  required DateTime now,
}) {
  final channels = prefs.channels;
  return <PlannedReminder>[
    if (channels.morning)
      _checkIn(
        ReminderChannel.morning,
        at: _nextDaily(now, prefs.morningTime),
        repeat: DateTimeComponents.time,
        title: 'Good morning',
        body: 'Take a minute to line up what today needs.',
      ),
    if (channels.review)
      _checkIn(
        ReminderChannel.review,
        at: _nextDaily(now, prefs.reviewTime),
        repeat: DateTimeComponents.time,
        title: 'Evening review',
        body: 'How did today go? Tick off what you finished.',
      ),
    if (channels.weeklyReview)
      _checkIn(
        ReminderChannel.weeklyReview,
        at: _nextWeekly(now, prefs.weeklyReviewTime, _weeklyReviewWeekday),
        repeat: DateTimeComponents.dayOfWeekAndTime,
        title: 'Weekly review',
        body: 'Look back at your week, then set up the next one.',
      ),
  ];
}

PlannedReminder _checkIn(
  ReminderChannel channel, {
  required DateTime at,
  required DateTimeComponents repeat,
  required String title,
  required String body,
}) =>
    PlannedReminder(
      id: _checkInIds[channel]!,
      channel: channel,
      at: at,
      title: title,
      body: body,
      payload: _payload(channel),
      repeat: repeat,
    );

/// Parse an `HH:MM` preference, falling back to midnight on anything malformed.
({int hour, int minute}) _hhmm(String value) {
  final parts = value.split(':');
  return (
    hour: int.tryParse(parts.first)?.clamp(0, 23) ?? 0,
    minute: parts.length > 1 ? (int.tryParse(parts[1])?.clamp(0, 59) ?? 0) : 0,
  );
}

DateTime _nextDaily(DateTime now, String hhmm) {
  final time = _hhmm(hhmm);
  final today = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  return today.isAfter(now)
      ? today
      : DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
}

DateTime _nextWeekly(DateTime now, String hhmm, int weekday) {
  var at = _nextDaily(now, hhmm);
  // Re-derive from calendar fields each step so a DST shift can't drag the
  // wall-clock time off the requested minute.
  while (at.weekday != weekday) {
    at = DateTime(at.year, at.month, at.day + 1, at.hour, at.minute);
  }
  return at;
}

/// Owns the device's reminder schedule. Reached through
/// [reminderSchedulerProvider]; call [reconcile] after anything that changes
/// what should be pending.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  /// Last successfully loaded preferences, so an offline reconcile can still
  /// re-derive the schedule instead of falling back to defaults and quietly
  /// re-enabling channels the user turned off.
  NotificationPrefs? _prefs;

  DateTime? _lastRun;
  Future<void>? _inFlight;
  bool _rerunQueued = false;
  bool _askedForPermission = false;

  /// Re-derive the whole schedule and apply the difference.
  ///
  /// Coalesced: concurrent calls share one run, and un-forced calls within
  /// [_debounce] of the last are dropped — resume, a revision bump and a task
  /// mutation often land together.
  Future<void> reconcile({bool force = false}) {
    if (!Env.localReminders) return Future<void>.value();

    final inFlight = _inFlight;
    if (inFlight != null) {
      // A forced call means state changed underneath a pass that may already
      // have read the old task list — saving a task during a resume-triggered
      // run is the common case. Queue exactly one follow-up so the new task
      // still gets its reminder without waiting for the next trigger.
      if (force) _rerunQueued = true;
      return inFlight;
    }

    final last = _lastRun;
    if (!force && last != null && DateTime.now().difference(last) < _debounce) {
      return Future<void>.value();
    }
    return _inFlight = _runLoop();
  }

  static const _debounce = Duration(seconds: 15);

  Future<void> _runLoop() async {
    try {
      do {
        _rerunQueued = false;
        await _run();
      } while (_rerunQueued);
    } finally {
      _inFlight = null;
      _rerunQueued = false;
    }
  }

  Future<void> _run() async {
    _lastRun = DateTime.now();

    final notifications = LocalNotifications.instance;
    await notifications.ensureInitialized();
    if (!notifications.ready) return;
    if (!_askedForPermission) {
      _askedForPermission = true;
      await notifications.requestPermission();
    }

    final prefs = await _loadPrefs();
    if (prefs == null) return;
    final tasks = await _loadTasks();
    // A failed load is not an empty schedule: bail and keep whatever is already
    // pending, so opening the app offline doesn't wipe the week's reminders.
    if (tasks == null) return;

    final now = DateTime.now();
    await _apply([
      ...planCheckIns(prefs, now: now),
      ...planTaskReminders(
        tasks: tasks,
        channels: prefs.channels,
        now: now,
      ),
    ]);
  }

  Future<NotificationPrefs?> _loadPrefs() async {
    try {
      return _prefs = await _ref
          .read(settingsRepositoryProvider)
          .getNotificationPrefs();
    } on Object catch (e) {
      debugPrint('ReminderScheduler: preferences unavailable — $e');
      return _prefs;
    }
  }

  Future<List<Task>?> _loadTasks() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    try {
      return await _ref
          .read(tasksRepositoryProvider)
          .tasksInRange(from, from.add(schedulingHorizon));
    } on Object catch (e) {
      debugPrint('ReminderScheduler: tasks unavailable — $e');
      return null;
    }
  }

  Future<void> _apply(List<PlannedReminder> planned) async {
    final plugin = LocalNotifications.instance.plugin;
    final desired = {for (final reminder in planned) reminder.id};

    // Cancel only what we no longer want. Everything pending in this plugin was
    // scheduled here — the push path only ever calls `show()`, which is
    // immediate and never pending — so this is safe, where `cancelAll()` would
    // also clear reminders already on screen.
    try {
      for (final pending in await plugin.pendingNotificationRequests()) {
        if (!desired.contains(pending.id)) await plugin.cancel(pending.id);
      }
    } on Object catch (e) {
      debugPrint('ReminderScheduler: could not read pending reminders — $e');
    }

    for (final reminder in planned) {
      try {
        await plugin.zonedSchedule(
          reminder.id,
          reminder.title,
          reminder.body,
          tz.TZDateTime.from(reminder.at, tz.local),
          reminderDetails,
          // Inexact deliberately: exact alarms need SCHEDULE_EXACT_ALARM, which
          // triggers a Play Store policy review, and a study reminder is fine
          // landing within a few minutes of its slot.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: reminder.repeat,
          payload: reminder.payload,
        );
      } on Object catch (e) {
        debugPrint('ReminderScheduler: could not schedule ${reminder.id} — $e');
      }
    }
  }

  /// Open the day a tapped reminder belongs to.
  void _handleTap(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map) return;
      final date = DateTime.tryParse(data['date'] as String? ?? '');
      if (date != null) {
        _ref.read(selectedDateProvider.notifier).select(date);
      }
      _ref.read(routerProvider).go(Routes.plan);
    } on Object catch (e) {
      debugPrint('ReminderScheduler: could not open reminder — $e');
    }
  }
}

/// Keeps the reminder schedule current. Watched at the app root (`app.dart`).
///
/// Reconciles on sign-in (the task list is per-user) and on every foreground
/// resume — which rolls the horizon forward and picks up anything changed
/// elsewhere. Mutations call [ReminderScheduler.reconcile] directly.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final scheduler = ReminderScheduler(ref);
  if (!Env.localReminders) return scheduler;

  LocalNotifications.instance.setTapHandler(scheduler._handleTap);

  ref.listen(authStateProvider, (_, next) {
    if (next.value != null) unawaited(scheduler.reconcile(force: true));
  }, fireImmediately: true);

  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(scheduler.reconcile()),
  );
  ref.onDispose(lifecycle.dispose);

  return scheduler;
});
