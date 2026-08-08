import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/data/models/user_settings.dart';
import 'package:aqademiq/services/reminder_scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scheduler's planning core is pure, so it is testable without the plugin
/// (which has no method channels under `flutter test`).
void main() {
  final now = DateTime(2026, 8, 9, 9);

  Task task({
    String id = 'series-1@2026-08-09',
    DateTime? startTime,
    int? durationMin,
    bool done = false,
  }) =>
      Task(
        id: id,
        title: 'Read chapter 4',
        tagId: 'study',
        date: DateTime(2026, 8, 9),
        startTime: startTime,
        durationMin: durationMin,
        done: done,
      );

  Set<ReminderChannel> channelsOf(List<PlannedReminder> planned) =>
      planned.map((r) => r.channel).toSet();

  group('planTaskReminders', () {
    test('covers all four task channels for a timed task', () {
      final planned = planTaskReminders(
        tasks: [task(startTime: DateTime(2026, 8, 9, 14), durationMin: 60)],
        channels: const NotificationChannels(
          taskHalf: true,
          taskEnd: true,
        ),
        now: now,
      );

      expect(channelsOf(planned), {
        ReminderChannel.beforeTask,
        ReminderChannel.taskStart,
        ReminderChannel.taskHalf,
        ReminderChannel.taskEnd,
      });
      final at = {for (final r in planned) r.channel: r.at};
      expect(at[ReminderChannel.beforeTask], DateTime(2026, 8, 9, 13, 50));
      expect(at[ReminderChannel.taskStart], DateTime(2026, 8, 9, 14));
      expect(at[ReminderChannel.taskHalf], DateTime(2026, 8, 9, 14, 30));
      expect(at[ReminderChannel.taskEnd], DateTime(2026, 8, 9, 15));
    });

    test('the before-task lead matches the backend REMINDER_LEAD_MS', () {
      expect(reminderLead, const Duration(minutes: 10));
    });

    test('honours the per-channel toggles', () {
      final planned = planTaskReminders(
        tasks: [task(startTime: DateTime(2026, 8, 9, 14), durationMin: 60)],
        channels: const NotificationChannels(taskStart: false),
        now: now,
      );
      expect(channelsOf(planned), {ReminderChannel.beforeTask});
    });

    test('skips completed tasks, date-only tasks, and times already past', () {
      final planned = planTaskReminders(
        tasks: [
          task(id: 'done@2026-08-09', startTime: DateTime(2026, 8, 9, 14), done: true),
          task(id: 'undated@2026-08-09'),
          task(id: 'past@2026-08-09', startTime: DateTime(2026, 8, 9, 8)),
        ],
        channels: const NotificationChannels(),
        now: now,
      );
      expect(planned, isEmpty);
    });

    test('drops tasks beyond the horizon', () {
      final planned = planTaskReminders(
        tasks: [task(id: 'far@2026-08-30', startTime: DateTime(2026, 8, 30, 14))],
        channels: const NotificationChannels(),
        now: now,
      );
      expect(planned, isEmpty);
    });

    test('half/end need a real duration to mean anything', () {
      final planned = planTaskReminders(
        tasks: [task(startTime: DateTime(2026, 8, 9, 14))],
        channels: const NotificationChannels(taskHalf: true, taskEnd: true),
        now: now,
      );
      expect(
        channelsOf(planned),
        {ReminderChannel.beforeTask, ReminderChannel.taskStart},
      );
    });

    test('keeps the soonest reminders when over the iOS budget', () {
      final tasks = [
        for (var i = 0; i < 40; i++)
          task(
            id: 'series-$i@2026-08-09',
            startTime: DateTime(2026, 8, 9, 12).add(Duration(minutes: i * 30)),
          ),
      ];
      final planned = planTaskReminders(
        tasks: tasks,
        channels: const NotificationChannels(),
        now: now,
        limit: 10,
      );

      expect(planned, hasLength(10));
      expect(planned.first.at, DateTime(2026, 8, 9, 11, 50));
      for (var i = 1; i < planned.length; i++) {
        expect(planned[i].at.isBefore(planned[i - 1].at), isFalse);
      }
    });

    test('ids are stable per occurrence+channel and distinct across them', () {
      final first = planTaskReminders(
        tasks: [task(startTime: DateTime(2026, 8, 9, 14))],
        channels: const NotificationChannels(),
        now: now,
      );
      final second = planTaskReminders(
        tasks: [task(startTime: DateTime(2026, 8, 9, 14))],
        channels: const NotificationChannels(),
        now: now,
      );

      expect(
        first.map((r) => r.id).toList(),
        second.map((r) => r.id).toList(),
      );
      expect(first.map((r) => r.id).toSet(), hasLength(first.length));
      // Must not collide with the fixed check-in ids, and must fit a Java int.
      for (final reminder in first) {
        expect(reminder.id, greaterThan(3));
        expect(reminder.id, lessThan(2147483647));
      }
    });
  });

  group('planCheckIns', () {
    test('schedules the next occurrence of each enabled check-in', () {
      final planned = planCheckIns(
        const NotificationPrefs(
          morningTime: '07:30',
          reviewTime: '21:15',
          weeklyReviewTime: '16:45',
        ),
        now: now,
      );
      final at = {for (final r in planned) r.channel: r.at};

      // 07:30 has already passed at 09:00, so morning rolls to tomorrow.
      expect(at[ReminderChannel.morning], DateTime(2026, 8, 10, 7, 30));
      expect(at[ReminderChannel.review], DateTime(2026, 8, 9, 21, 15));
      // 2026-08-09 is a Sunday and 16:45 is still ahead.
      expect(at[ReminderChannel.weeklyReview], DateTime(2026, 8, 9, 16, 45));
      expect(at[ReminderChannel.weeklyReview]!.weekday, DateTime.sunday);
    });

    test('repeats rather than materialising one-shots', () {
      final planned = planCheckIns(const NotificationPrefs(), now: now);
      final repeats = {for (final r in planned) r.channel: r.repeat};
      expect(repeats[ReminderChannel.morning], DateTimeComponents.time);
      expect(repeats[ReminderChannel.review], DateTimeComponents.time);
      expect(
        repeats[ReminderChannel.weeklyReview],
        DateTimeComponents.dayOfWeekAndTime,
      );
    });

    test('omits disabled check-ins', () {
      final planned = planCheckIns(
        const NotificationPrefs(
          channels: NotificationChannels(morning: false, weeklyReview: false),
        ),
        now: now,
      );
      expect(planned.map((r) => r.channel), [ReminderChannel.review]);
    });

    test('a malformed time falls back to midnight rather than throwing', () {
      final planned = planCheckIns(
        const NotificationPrefs(morningTime: 'not-a-time'),
        now: now,
      );
      final morning =
          planned.firstWhere((r) => r.channel == ReminderChannel.morning);
      expect(morning.at, DateTime(2026, 8, 10));
    });
  });
}
