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

    // A deliberately *mid-week* fixture, because that is the state the report is
    // in for five days out of seven and the one with the most ways to be wrong.
    // Today is treated as Thursday: Monday to Thursday have happened, and
    // Friday to Sunday have not.
    //
    // The three band states the design turns on are all present, which is the
    // point of the fixture — on a week where every day is full, none of them is
    // visible and all three are easy to break:
    //   Mon/Tue/Fri…  tinted   — a mood was logged
    //   Wed           untinted — work happened, no check-in
    //   Thu           open     — today, and nothing on it yet
    //   Fri/Sat/Sun   not yet  — must never draw as "nothing logged"
    const elapsed = 4;
    return mockDelay(
      WeeklyReportDto(
        weekStart: d(0),
        weekEnd: d(6),
        shape: 'clustered',
        activeDays: 3,
        elapsedDays: elapsed,
        daysOnBoard: 23,
        days: [
          WeeklyReportDayDto(date: d(0), weekday: 1, moodIndex: 1, hasActivity: true, tasksCompleted: 1, focusMinutes: 25, focusSessions: 1),
          WeeklyReportDayDto(date: d(1), weekday: 2, moodIndex: 3, hasActivity: true, tasksCompleted: 3, focusMinutes: 75, focusSessions: 2),
          WeeklyReportDayDto(date: d(2), weekday: 3, hasActivity: true, tasksCompleted: 2, focusMinutes: 50, focusSessions: 2),
          WeeklyReportDayDto(date: d(3), weekday: 4),
          WeeklyReportDayDto(date: d(4), weekday: 5, isFuture: true),
          WeeklyReportDayDto(date: d(5), weekday: 6, isFuture: true),
          WeeklyReportDayDto(date: d(6), weekday: 7, isFuture: true),
        ],
        subjects: const [
          ReportSubjectDto(subjectId: 's1', name: 'Machine Learning', color: '#6B5CF0', focusMinutes: 90, tasksCompleted: 4, share: 0.6),
          ReportSubjectDto(subjectId: 's2', name: 'Linear Algebra', color: '#2A9D6B', focusMinutes: 40, tasksCompleted: 2, share: 0.27),
          ReportSubjectDto(subjectId: 's3', name: 'Thermodynamics', color: '#E85476', focusMinutes: 20, tasksCompleted: 1, share: 0.13),
        ],
        moment: ReportMomentDto(date: d(2), title: 'Finish the reading you moved twice', subjectId: 's1'),
        recovery: const ReportRecoveryDto(sessions: 4, beforeAvg: 2.25, afterAvg: 3.5, lift: 1.25),
        longestSession: ReportLongestDto(minutes: 52, date: d(1), taskTitle: 'Problem set 4'),
        heldMinutes: 18,
        prismMix: const [
          ReportPrismSliceDto(presetId: 'p1', name: 'Rain', sessions: 5, share: 0.56),
          ReportPrismSliceDto(presetId: 'p2', name: 'Deep Work', sessions: 3, share: 0.33),
          ReportPrismSliceDto(presetId: 'p3', name: 'Forest', sessions: 1, share: 0.11),
        ],
        rhythmWeekdays: const [2, 3, 5],
        focusMinutes: 150,
        focusSessions: 5,
        tasksCompleted: 6,
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
