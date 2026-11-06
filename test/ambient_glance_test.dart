import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/mood_log.dart';
import 'package:aqademiq/data/models/tag.dart';
import 'package:aqademiq/data/models/task.dart';
import 'package:aqademiq/services/ambient/ambient_glance.dart';
import 'package:aqademiq/services/ambient/ambient_state.dart';
import 'package:flutter_test/flutter_test.dart';

final _day = DateTime(2026, 8, 12); // A Wednesday.

Task _task(
  String title, {
  int? hour,
  bool done = false,
  String tagId = '',
}) =>
    Task(
      id: title,
      title: title,
      date: _day,
      done: done,
      tagId: tagId,
      startTime: hour == null ? null : DateTime(2026, 8, 12, hour),
    );

MoodLog _log(DateTime date) =>
    MoodLog(id: '$date', date: date, phase: MoodPhase.morning, mood: 3);

MoodLog _mood(
  DateTime date,
  int mood, {
  MoodPhase phase = MoodPhase.morning,
}) =>
    MoodLog(id: '$date-${phase.name}', date: date, phase: phase, mood: mood);

void main() {
  group('next', () {
    test('is the earliest thing still ahead today', () {
      final tasks = [
        _task('Reading', hour: 16),
        _task('Ch. 4 problem set', hour: 14),
        _task('Gym', hour: 18),
      ];

      final next = nextTaskFrom(tasks, now: DateTime(2026, 8, 12, 10));
      expect(next?.title, 'Ch. 4 problem set');
    });

    test('skips what is already done', () {
      final tasks = [
        _task('Ch. 4 problem set', hour: 14, done: true),
        _task('Reading', hour: 16),
      ];

      expect(nextTaskFrom(tasks, now: DateTime(2026, 8, 12, 10))?.title, 'Reading');
    });

    test('a late task is still next, not skipped', () {
      // It has not stopped needing doing just because it is overdue, and
      // silently jumping past it would quietly lose the student's day.
      final tasks = [_task('Ch. 4 problem set', hour: 9)];

      expect(
        nextTaskFrom(tasks, now: DateTime(2026, 8, 12, 15))?.title,
        'Ch. 4 problem set',
      );
    });

    test('prefers something upcoming over something overdue', () {
      final tasks = [
        _task('Missed lecture', hour: 9),
        _task('Ch. 4 problem set', hour: 16),
      ];

      expect(
        nextTaskFrom(tasks, now: DateTime(2026, 8, 12, 15))?.title,
        'Ch. 4 problem set',
      );
    });

    test('falls back to an untimed task when nothing is scheduled', () {
      expect(nextTaskFrom([_task('Read a chapter')])?.title, 'Read a chapter');
    });

    test('an empty or finished day has no next', () {
      expect(nextTaskFrom(const []), isNull);
      expect(nextTaskFrom([_task('Done thing', hour: 9, done: true)]), isNull);
    });
  });

  group('this week', () {
    test('marks the days that were logged, Monday first', () {
      final monday = DateTime(2026, 8, 10);
      final logs = [
        _log(monday),
        _log(monday.add(const Duration(days: 1))),
        _log(monday.add(const Duration(days: 3))),
      ];

      expect(
        weekDaysFrom(logs, now: _day),
        [true, true, false, true, false, false, false],
      );
    });

    test('is always seven, even with nothing logged', () {
      final week = weekDaysFrom(const [], now: _day);
      expect(week.length, 7);
      expect(week.every((d) => !d), isTrue);
    });

    test('ignores logs from other weeks', () {
      final lastWeek = DateTime(2026, 8, 3);
      expect(
        weekDaysFrom([_log(lastWeek)], now: _day),
        everyElement(isFalse),
      );
    });
  });

  group('this week, by mood', () {
    test('carries the mood logged each day, Monday first', () {
      final monday = DateTime(2026, 8, 10);
      final logs = [
        _mood(monday, 3),
        _mood(monday.add(const Duration(days: 1)), 2),
      ];

      // wg-home's own week: Monday Good, Tuesday OK, nothing yet today.
      expect(
        weekMoodsFrom(logs, now: _day),
        [3, 2, null, null, null, null, null],
      );
    });

    test('a day with nothing logged is null — an outline, never a puddle', () {
      final week = weekMoodsFrom(const [], now: _day);
      expect(week.length, 7);
      expect(week, everyElement(isNull));
    });

    test('a day with two check-ins shows the later one', () {
      final tuesday = DateTime(2026, 8, 11);
      expect(
        weekMoodsFrom(
          [
            _mood(tuesday, 1, phase: MoodPhase.evening),
            _mood(tuesday, 4),
          ],
          now: _day,
        )[1],
        1,
      );
      expect(
        weekMoodsFrom(
          [
            _mood(DateTime(2026, 8, 11, 8), 4),
            _mood(DateTime(2026, 8, 11, 21), 0),
          ],
          now: _day,
        )[1],
        0,
      );
    });

    test('agrees with the days marked as shown up for', () {
      final monday = DateTime(2026, 8, 10);
      final logs = [
        _mood(monday, 4),
        _mood(monday.add(const Duration(days: 3)), 0),
      ];
      final days = weekDaysFrom(logs, now: _day);
      final moods = weekMoodsFrom(logs, now: _day);
      for (var i = 0; i < 7; i++) {
        expect(moods[i] != null, days[i], reason: 'day $i');
      }
    });

    test('keeps a mood on the scale, whatever was stored', () {
      final monday = DateTime(2026, 8, 10);
      final logs = [
        _mood(monday, 9),
        _mood(monday.add(const Duration(days: 1)), -2),
      ];
      expect(weekMoodsFrom(logs, now: _day).take(2).toList(), [4, 0]);
    });

    test('ignores logs from other weeks', () {
      expect(
        weekMoodsFrom([_mood(DateTime(2026, 8, 3), 3)], now: _day),
        everyElement(isNull),
      );
    });
  });

  group('the published payload', () {
    test('carries the next task with its subject and tint', () {
      final state = glanceState(
        tasks: [_task('Ch. 4 problem set', hour: 14, tagId: 'la')],
        weekLogs: [_log(DateTime(2026, 8, 10))],
        tagsById: {
          'la': const Tag(id: 'la', label: 'Linear Algebra', color: '#6b5cf0'),
        },
        todayFocusMin: 42,
        now: DateTime(2026, 8, 12, 10),
      );

      expect(state.nextTaskTitle, 'Ch. 4 problem set');
      expect(state.nextTaskSubject, 'Linear Algebra');
      expect(state.nextTaskTint, '#6b5cf0');
      expect(state.nextTaskTime, isNotNull);
      expect(state.todayFocusMin, 42);
      expect(state.weekDays.length, 7);
      expect(state.weekMoods, [3, null, null, null, null, null, null]);
      // Stamped with the row's Monday and the count's day, so a surface drawn
      // after the rollover can tell the week (or the day) has moved on.
      expect(state.weekOf, '2026-08-10');
      expect(state.focusDay, '2026-08-12');
    });

    test('an empty day says nothing rather than something wrong', () {
      final state = glanceState(tasks: const [], weekLogs: const [], now: _day);
      expect(state.nextTaskTitle, isNull);
      expect(state.nextTaskTime, isNull);
    });

    test('threads the running session through untouched', () {
      // Publishing what the widgets show must never disturb a live session.
      final state = glanceState(
        tasks: const [],
        weekLogs: const [],
        now: _day,
        session: AmbientSession(
          endsAt: DateTime(2026, 8, 12, 15),
          frozen: false,
          meltStage: 2,
          remainingSec: 600,
          durationSec: 1500,
        ),
      );
      expect(state.session, isNotNull);
      expect(state.session!.meltStage, 2);
    });
  });
}
