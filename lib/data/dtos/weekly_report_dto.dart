/// Wire DTOs for the weekly report (`GET /v1/me/weekly-report`).
///
/// Hand-written and codegen-free, like `feedback_dto.dart` and `models/enums.dart`
/// — the shape mirrors the freezed DTOs elsewhere in `data/dtos` without needing
/// a `build_runner` pass to land.
///
/// Every field parses defensively. This payload is drawn as a whole screen with
/// no partial state, so one unexpected null must not take the report down; a
/// missing card is a card that does not render, which is exactly what the
/// design already asks for.
///
/// The server sends facts only — no sentence, label or adjective crosses the
/// wire. All copy is templated in `features/report`, where the banned-word lint
/// can see it as a string literal.
library;

class WeeklyReportDayDto {
  const WeeklyReportDayDto({
    required this.date,
    required this.weekday,
    this.moodIndex,
    this.hasActivity = false,
    this.tasksCompleted = 0,
    this.focusMinutes = 0,
    this.focusSessions = 0,
  });

  factory WeeklyReportDayDto.fromJson(Map<String, dynamic> j) =>
      WeeklyReportDayDto(
        date: j['date'] as String? ?? '',
        weekday: (j['weekday'] as num?)?.toInt() ?? 1,
        moodIndex: (j['mood_index'] as num?)?.toInt(),
        hasActivity: j['has_activity'] as bool? ?? false,
        tasksCompleted: (j['tasks_completed'] as num?)?.toInt() ?? 0,
        focusMinutes: (j['focus_minutes'] as num?)?.toInt() ?? 0,
        focusSessions: (j['focus_sessions'] as num?)?.toInt() ?? 0,
      );

  final String date;

  /// 1 = Monday … 7 = Sunday.
  final int weekday;

  /// 0–4 on the shipped mood ramp, or null when nothing was logged.
  final int? moodIndex;
  final bool hasActivity;
  final int tasksCompleted;
  final int focusMinutes;
  final int focusSessions;
}

class ReportSubjectDto {
  const ReportSubjectDto({
    required this.subjectId,
    this.name,
    this.color,
    this.focusMinutes = 0,
    this.tasksCompleted = 0,
    this.share = 0,
  });

  factory ReportSubjectDto.fromJson(Map<String, dynamic> j) => ReportSubjectDto(
        subjectId: j['subject_id'] as String? ?? '',
        name: j['name'] as String?,
        color: j['color'] as String?,
        focusMinutes: (j['focus_minutes'] as num?)?.toInt() ?? 0,
        tasksCompleted: (j['tasks_completed'] as num?)?.toInt() ?? 0,
        share: (j['share'] as num?)?.toDouble() ?? 0,
      );

  final String subjectId;

  /// Null when the subject was deleted after the work happened. It keeps its
  /// share of the week; it just has no name to print.
  final String? name;
  final String? color;
  final int focusMinutes;
  final int tasksCompleted;
  final double share;
}

class ReportMomentDto {
  const ReportMomentDto({required this.date, required this.title, this.subjectId});

  factory ReportMomentDto.fromJson(Map<String, dynamic> j) => ReportMomentDto(
        date: j['date'] as String? ?? '',
        title: j['title'] as String? ?? '',
        subjectId: j['subject_id'] as String?,
      );

  final String date;
  final String title;
  final String? subjectId;
}

class ReportRecoveryDto {
  const ReportRecoveryDto({
    required this.sessions,
    required this.beforeAvg,
    required this.afterAvg,
    required this.lift,
  });

  factory ReportRecoveryDto.fromJson(Map<String, dynamic> j) => ReportRecoveryDto(
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
        beforeAvg: (j['before_avg'] as num?)?.toDouble() ?? 0,
        afterAvg: (j['after_avg'] as num?)?.toDouble() ?? 0,
        lift: (j['lift'] as num?)?.toDouble() ?? 0,
      );

  final int sessions;
  final double beforeAvg;
  final double afterAvg;

  /// Always > 0 — the server returns null rather than a lift that points the
  /// wrong way, so this object existing *is* the good news.
  final double lift;
}

class ReportLongestDto {
  const ReportLongestDto({required this.minutes, required this.date, this.taskTitle});

  factory ReportLongestDto.fromJson(Map<String, dynamic> j) => ReportLongestDto(
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        date: j['date'] as String? ?? '',
        taskTitle: j['task_title'] as String?,
      );

  final int minutes;
  final String date;
  final String? taskTitle;
}

class ReportPrismSliceDto {
  const ReportPrismSliceDto({
    required this.presetId,
    required this.name,
    this.sessions = 0,
    this.share = 0,
  });

  factory ReportPrismSliceDto.fromJson(Map<String, dynamic> j) => ReportPrismSliceDto(
        presetId: j['preset_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
        share: (j['share'] as num?)?.toDouble() ?? 0,
      );

  final String presetId;
  final String name;
  final int sessions;
  final double share;
}

class WeeklyReportDto {
  const WeeklyReportDto({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    // Not 'empty'. A payload that omits the shape is a payload we could not
    // read, and rendering that as "nothing happened this week" states something
    // false about the student. 'scattered' is the value that claims nothing;
    // 'empty' only ever arrives because the server explicitly said so.
    this.shape = 'scattered',
    this.activeDays = 0,
    this.daysOnBoard = 0,
    this.subjects = const [],
    this.subjectBasis = 'focus_minutes',
    this.unattributedFocusMinutes = 0,
    this.unattributedTasksCompleted = 0,
    this.moment,
    this.recovery,
    this.longestSession,
    this.heldMinutes = 0,
    this.prismMix = const [],
    this.rhythmWeekdays = const [],
    this.focusMinutes = 0,
    this.focusSessions = 0,
    this.tasksCompleted = 0,
  });

  factory WeeklyReportDto.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = j[key];
      if (raw is! List) return const [];
      return raw.whereType<Map<String, dynamic>>().map(parse).toList(growable: false);
    }

    Map<String, dynamic>? obj(String key) {
      final raw = j[key];
      return raw is Map<String, dynamic> ? raw : null;
    }

    final moment = obj('moment');
    final recovery = obj('recovery');
    final longest = obj('longest_session');
    final rhythm = j['rhythm_weekdays'];

    return WeeklyReportDto(
      weekStart: j['week_start'] as String? ?? '',
      weekEnd: j['week_end'] as String? ?? '',
      days: list('days', WeeklyReportDayDto.fromJson),
      shape: j['shape'] as String? ?? 'scattered',
      activeDays: (j['active_days'] as num?)?.toInt() ?? 0,
      daysOnBoard: (j['days_on_board'] as num?)?.toInt() ?? 0,
      subjects: list('subjects', ReportSubjectDto.fromJson),
      subjectBasis: j['subject_basis'] as String? ?? 'focus_minutes',
      unattributedFocusMinutes: (j['unattributed_focus_minutes'] as num?)?.toInt() ?? 0,
      unattributedTasksCompleted: (j['unattributed_tasks_completed'] as num?)?.toInt() ?? 0,
      moment: moment == null ? null : ReportMomentDto.fromJson(moment),
      recovery: recovery == null ? null : ReportRecoveryDto.fromJson(recovery),
      longestSession: longest == null ? null : ReportLongestDto.fromJson(longest),
      heldMinutes: (j['held_minutes'] as num?)?.toInt() ?? 0,
      prismMix: list('prism_mix', ReportPrismSliceDto.fromJson),
      rhythmWeekdays: rhythm is List
          ? rhythm.whereType<num>().map((n) => n.toInt()).toList(growable: false)
          : const [],
      focusMinutes: (j['focus_minutes'] as num?)?.toInt() ?? 0,
      focusSessions: (j['focus_sessions'] as num?)?.toInt() ?? 0,
      tasksCompleted: (j['tasks_completed'] as num?)?.toInt() ?? 0,
    );
  }

  final String weekStart;
  final String weekEnd;
  final List<WeeklyReportDayDto> days;
  final String shape;
  final int activeDays;

  /// Lifetime days on the board. The hero numeral, and the only count here that
  /// cannot go down.
  final int daysOnBoard;
  final List<ReportSubjectDto> subjects;

  /// `focus_minutes` or `tasks_completed` — which unit `share` was computed in.
  final String subjectBasis;
  final int unattributedFocusMinutes;
  final int unattributedTasksCompleted;
  final ReportMomentDto? moment;
  final ReportRecoveryDto? recovery;
  final ReportLongestDto? longestSession;
  final int heldMinutes;
  final List<ReportPrismSliceDto> prismMix;

  /// Weekdays (1–7) that reliably carry work. Empty until there is enough
  /// history to say anything, which is most accounts.
  final List<int> rhythmWeekdays;
  final int focusMinutes;
  final int focusSessions;
  final int tasksCompleted;
}
