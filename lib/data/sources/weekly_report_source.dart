import 'package:dio/dio.dart';

import '../dtos/weekly_report_dto.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// `GET /v1/me/weekly-report?week_start=` — every fact the weekly Core draws,
/// in one read.
///
/// One endpoint rather than five composed client-side, because the report is a
/// single screen that appears all at once: five sequential round-trips on a
/// cold isolate is a visibly assembling dashboard, which is the exact thing
/// this design is not.
abstract interface class WeeklyReportSource {
  /// [inWeek] may be any date inside the week; the server snaps to Monday.
  /// Omitted means the current week.
  Future<WeeklyReportDto> report({DateTime? inWeek});
}

class MockWeeklyReportSource implements WeeklyReportSource {
  @override
  Future<WeeklyReportDto> report({DateTime? inWeek}) {
    final monday = mondayOf(inWeek ?? DateTime.now());
    String d(int i) => ymd(monday.add(Duration(days: i)));

    // A deliberately *ordinary* week: a quiet start, a run that held, one day
    // with nothing logged, and a weekend that tapers. Mock mode has to exercise
    // the two cases the design turns on — an untinted band (Wednesday: work
    // happened, no mood logged) and a genuinely empty one (Thursday) — because
    // those are the ones that are easy to draw wrong and impossible to notice
    // on a fixture where every day is full.
    return mockDelay(
      WeeklyReportDto(
        weekStart: d(0),
        weekEnd: d(6),
        shape: 'clustered',
        activeDays: 5,
        daysOnBoard: 23,
        days: [
          WeeklyReportDayDto(date: d(0), weekday: 1, moodIndex: 1, hasActivity: true, tasksCompleted: 1, focusMinutes: 25, focusSessions: 1),
          WeeklyReportDayDto(date: d(1), weekday: 2, moodIndex: 3, hasActivity: true, tasksCompleted: 3, focusMinutes: 75, focusSessions: 2),
          WeeklyReportDayDto(date: d(2), weekday: 3, hasActivity: true, tasksCompleted: 2, focusMinutes: 50, focusSessions: 2),
          WeeklyReportDayDto(date: d(3), weekday: 4),
          WeeklyReportDayDto(date: d(4), weekday: 5, moodIndex: 4, hasActivity: true, tasksCompleted: 2, focusMinutes: 90, focusSessions: 3),
          WeeklyReportDayDto(date: d(5), weekday: 6, moodIndex: 2, hasActivity: true, tasksCompleted: 1, focusMinutes: 30, focusSessions: 1),
          WeeklyReportDayDto(date: d(6), weekday: 7),
        ],
        subjects: const [
          ReportSubjectDto(subjectId: 's1', name: 'Machine Learning', color: '#6B5CF0', focusMinutes: 130, tasksCompleted: 4, share: 0.48),
          ReportSubjectDto(subjectId: 's2', name: 'Linear Algebra', color: '#2A9D6B', focusMinutes: 85, tasksCompleted: 3, share: 0.31),
          ReportSubjectDto(subjectId: 's3', name: 'Thermodynamics', color: '#E85476', focusMinutes: 35, tasksCompleted: 1, share: 0.13),
        ],
        moment: ReportMomentDto(date: d(2), title: 'Finish the reading you moved twice', subjectId: 's1'),
        recovery: const ReportRecoveryDto(sessions: 4, beforeAvg: 2.25, afterAvg: 3.5, lift: 1.25),
        longestSession: ReportLongestDto(minutes: 52, date: d(4), taskTitle: 'Problem set 4'),
        heldMinutes: 18,
        prismMix: const [
          ReportPrismSliceDto(presetId: 'p1', name: 'Rain', sessions: 5, share: 0.56),
          ReportPrismSliceDto(presetId: 'p2', name: 'Deep Hum', sessions: 3, share: 0.33),
          ReportPrismSliceDto(presetId: 'p3', name: 'Library', sessions: 1, share: 0.11),
        ],
        rhythmWeekdays: const [2, 3, 5],
        focusMinutes: 270,
        focusSessions: 9,
        tasksCompleted: 9,
      ),
    );
  }
}

class ApiWeeklyReportSource implements WeeklyReportSource {
  ApiWeeklyReportSource(this._dio);
  final Dio _dio;

  @override
  Future<WeeklyReportDto> report({DateTime? inWeek}) async {
    final j = await _dio.getMap(
      '/me/weekly-report',
      query: inWeek == null ? null : {'week_start': ymd(inWeek)},
    );
    return WeeklyReportDto.fromJson(j);
  }
}
