// The weekly report's data path, and the one drawing decision inside it.
//
// The report is rendered as a whole screen with no partial state — there is no
// per-card loading and no per-card error. That makes the parse the single point
// where a surprising payload becomes either a missing card (fine) or a blank
// screen (not fine), so it is tested against a payload that is missing almost
// everything, not just a well-formed one.
//
// The drawing decision is what a band means. There are three states and they
// are easy to collapse into two, which is how a report ends up telling someone
// they had a bad day when what actually happened is that they did not log one.

import 'package:aqademiq/core/theme/app_mood.dart';
import 'package:aqademiq/data/adapters/adapters.dart';
import 'package:aqademiq/data/dtos/weekly_report_dto.dart';
import 'package:aqademiq/data/models/weekly_report.dart';
import 'package:aqademiq/data/sources/weekly_report_source.dart';
import 'package:flutter_test/flutter_test.dart';

const _full = <String, dynamic>{
  'week_start': '2026-08-31',
  'week_end': '2026-09-06',
  'shape': 'clustered',
  'active_days': 4,
  'days_on_board': 23,
  'days': [
    {'date': '2026-08-31', 'weekday': 1, 'mood_index': 1, 'has_activity': true, 'tasks_completed': 1, 'focus_minutes': 25, 'focus_sessions': 1},
    {'date': '2026-09-01', 'weekday': 2, 'mood_index': 0, 'has_activity': true, 'tasks_completed': 2, 'focus_minutes': 50, 'focus_sessions': 2},
    {'date': '2026-09-02', 'weekday': 3, 'mood_index': null, 'has_activity': true, 'tasks_completed': 1, 'focus_minutes': 30, 'focus_sessions': 1},
    {'date': '2026-09-03', 'weekday': 4, 'has_activity': false},
    {'date': '2026-09-04', 'weekday': 5, 'mood_index': 4, 'has_activity': true, 'tasks_completed': 3, 'focus_minutes': 90, 'focus_sessions': 3},
    {'date': '2026-09-05', 'weekday': 6, 'has_activity': false},
    {'date': '2026-09-06', 'weekday': 7, 'has_activity': false},
  ],
  'subjects': [
    {'subject_id': 's1', 'name': 'Machine Learning', 'color': '#6B5CF0', 'focus_minutes': 130, 'tasks_completed': 4, 'share': 0.6},
    {'subject_id': 's2', 'name': null, 'color': null, 'focus_minutes': 65, 'tasks_completed': 2, 'share': 0.3},
  ],
  'subject_basis': 'focus_minutes',
  'moment': {'date': '2026-09-02', 'title': 'Reading', 'subject_id': 's1'},
  'recovery': {'sessions': 3, 'before_avg': 2.0, 'after_avg': 3.4, 'lift': 1.4},
  'longest_session': {'minutes': 52, 'date': '2026-09-04', 'task_title': 'Problem set'},
  'held_minutes': 18,
  'prism_mix': [
    {'preset_id': 'p1', 'name': 'Rain', 'sessions': 5, 'share': 0.62},
  ],
  'rhythm_weekdays': [2, 3, 5],
  'focus_minutes': 195,
  'focus_sessions': 7,
  'tasks_completed': 7,
};

void main() {
  group('parsing', () {
    test('a full payload round-trips onto the model', () {
      final r = WeeklyReportDto.fromJson(_full).toModel();

      expect(r.days, hasLength(7));
      expect(r.shape, WeekShape.clustered);
      expect(r.daysOnBoard, 23);
      expect(r.subjects, hasLength(2));
      expect(r.moment?.title, 'Reading');
      expect(r.recovery?.lift, 1.4);
      expect(r.longestSession?.minutes, 52);
      expect(r.heldMinutes, 18);
      expect(r.prismMix.single.name, 'Rain');
      expect(r.rhythmWeekdays, [2, 3, 5]);
    });

    test('an empty object parses instead of throwing', () {
      // The screen has no partial state. A payload this degenerate has to
      // produce a report that renders every beat as absent, not an exception
      // halfway down a ListView the student is already looking at.
      final r = WeeklyReportDto.fromJson(const {}).toModel();
      expect(r.days, isEmpty);
      expect(r.shape, WeekShape.scattered);
      expect(r.moment, isNull);
      expect(r.recovery, isNull);
      expect(r.longestSession, isNull);
      expect(r.isEmpty, isTrue);
    });

    test('wrong-typed collections are ignored rather than fatal', () {
      final r = WeeklyReportDto.fromJson(const {
        'days': 'not a list',
        'subjects': {'not': 'a list'},
        'moment': 'not an object',
        'rhythm_weekdays': [1, 'two', 3],
      }).toModel();
      expect(r.days, isEmpty);
      expect(r.subjects, isEmpty);
      expect(r.moment, isNull);
      expect(r.rhythmWeekdays, [1, 3]);
    });

    test('an unknown shape becomes the one that claims nothing', () {
      // Not `empty`. A server that adds a shape this build does not know must
      // not have its new value render as "nothing happened this week".
      final r = WeeklyReportDto.fromJson(const {'shape': 'avalanche'}).toModel();
      expect(r.shape, WeekShape.scattered);
    });

    test('a subject with no name keeps its share', () {
      final r = WeeklyReportDto.fromJson(_full).toModel();
      final nameless = r.subjects.firstWhere((s) => s.name == null);
      expect(nameless.share, 0.3);
      expect(nameless.focusMinutes, 65);
    });

    test('unattributed share is whatever the named subjects do not own', () {
      final r = WeeklyReportDto.fromJson(_full).toModel();
      expect(r.unattributedShare, closeTo(0.1, 0.0001));
    });

    test('unattributed share never goes negative on rounding drift', () {
      // Shares are rounded server-side to three places, so seven subjects can
      // sum to slightly over 1. A negative flex would throw in the layout.
      final r = WeeklyReportDto.fromJson(const {
        'subjects': [
          {'subject_id': 'a', 'share': 0.5},
          {'subject_id': 'b', 'share': 0.51},
        ],
      }).toModel();
      expect(r.unattributedShare, 0);
    });
  });

  group('what a band means', () {
    late WeeklyReport report;

    setUp(() => report = WeeklyReportDto.fromJson(_full).toModel());

    test('a day with nothing logged has no tint', () {
      final blank = report.days[3];
      expect(blank.hasActivity, isFalse);
      expect(AppMood.tint(blank.moodIndex), isNull);
    });

    test('a day that happened without a check-in is drawn, but untinted', () {
      // The state that is easy to lose. Wednesday had work and no mood. It must
      // not be an empty band (that would say nothing happened) and it must not
      // be tinted (there is no mood to tint it with).
      final worked = report.days[2];
      expect(worked.hasActivity, isTrue);
      expect(worked.isUntinted, isTrue);
      expect(AppMood.tint(worked.moodIndex), isNull);
    });

    test('the lowest mood is a real tint, not a missing one', () {
      // mood_index 0 is falsy. A truthiness check anywhere on this path turns
      // the worst day someone logged into a day they did not log — silently.
      final lowest = report.days[1];
      expect(lowest.moodIndex, 0);
      expect(AppMood.tint(0), isNotNull);
      expect(AppMood.tint(0), AppMood.ramp.first);
      expect(lowest.isUntinted, isFalse);
    });

    test('an out-of-range mood index does not index off the ramp', () {
      expect(AppMood.tint(-1), isNull);
      expect(AppMood.tint(5), isNull);
      expect(AppMood.tint(99), isNull);
    });
  });

  group('the mock exercises the cases the design turns on', () {
    test('it contains both an empty band and an untinted one', () {
      // Mock mode is where this UI gets looked at day to day. A fixture where
      // every day is full would let both of the failure modes above ship
      // without anyone seeing them.
      return MockWeeklyReportSource().report().then((dto) {
        final r = dto.toModel();
        expect(r.days, hasLength(7));
        expect(r.days.any((d) => !d.hasActivity), isTrue, reason: 'no empty band in the fixture');
        expect(r.days.any((d) => d.isUntinted), isTrue, reason: 'no untinted band in the fixture');
      });
    });

    test('its week starts on a Monday', () {
      return MockWeeklyReportSource().report().then((dto) {
        final r = dto.toModel();
        expect(r.days.first.date.weekday, DateTime.monday);
        expect(r.weekStart.weekday, DateTime.monday);
      });
    });
  });
}
