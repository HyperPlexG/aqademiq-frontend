/// The weekly report — an ice core drilled out of the last seven days.
///
/// Codegen-free for the same reason as `feedback_dto.dart`: this landed without
/// a `build_runner` pass, and nothing outside `data/` can tell the difference.
///
/// The model exists rather than the screen reading the DTO directly because two
/// things in here are load-bearing and must not be decided in a widget:
///
///  * [WeekShape] — the wire sends a string. An unknown value has to become
///    something safe rather than throwing halfway through a screen the student
///    is already looking at.
///  * [ReportDay.isUntinted] — a day with no mood is an *empty band*, never a
///    tinted one. That is the difference between "nothing logged" and a bad
///    day, and it is the single easiest way for this feature to say something
///    false about someone. The tint itself is decided once, in `AppMood.tint`.
library;

/// The week's shape, as classified by the server from which days carried work.
///
/// Deliberately about the week and never about the person: every value here
/// describes a distribution, and none of them is better or worse than another.
enum WeekShape {
  /// Nothing logged at all. A real week, described as what it was.
  empty,

  /// Exactly one day. Never rounded up into [scattered] — one day is a real
  /// week for somebody, and it deserves a sentence that is true.
  single,

  /// Spread across most of the week.
  steady,

  /// The weight is early.
  frontLoaded,

  /// The weight is late.
  backLoaded,

  /// A consecutive run.
  clustered,

  /// Present, with no discernible pattern.
  scattered;

  /// Wire value → shape. Unknown values fall back to [scattered], which is the
  /// only value that claims nothing: a new server shape must not crash a screen
  /// or, worse, silently render as [empty] and tell someone their week was
  /// blank when it was not.
  static WeekShape fromWire(String? wire) => switch (wire) {
        'empty' => WeekShape.empty,
        'single' => WeekShape.single,
        'steady' => WeekShape.steady,
        'front_loaded' => WeekShape.frontLoaded,
        'back_loaded' => WeekShape.backLoaded,
        'clustered' => WeekShape.clustered,
        _ => WeekShape.scattered,
      };
}

/// Which unit the subject shares were computed in.
enum SubjectBasis {
  focusMinutes,
  tasksCompleted;

  static SubjectBasis fromWire(String? wire) =>
      wire == 'tasks_completed' ? SubjectBasis.tasksCompleted : SubjectBasis.focusMinutes;
}

/// One band of the core.
class ReportDay {
  const ReportDay({
    required this.date,
    required this.weekday,
    required this.hasActivity,
    this.isFuture = false,
    this.moodIndex,
    this.tasksCompleted = 0,
    this.focusMinutes = 0,
    this.focusSessions = 0,
  });

  final DateTime date;

  /// 1 = Monday … 7 = Sunday.
  final int weekday;

  /// 0–4 on the shipped ramp, or null when nothing was logged.
  final int? moodIndex;

  /// Whether anything at all happened — tasks, focus, or a check-in.
  final bool hasActivity;

  /// A day later in the week than today. It has not happened, so it is neither
  /// active nor a gap: drawing it as "nothing logged" would tell someone on
  /// Thursday that they had already missed Friday, Saturday and Sunday.
  final bool isFuture;
  final int tasksCompleted;
  final int focusMinutes;
  final int focusSessions;

  /// A day that happened but carries no mood. The band is drawn, but it cannot
  /// be tinted, because there is no mood to tint it with.
  bool get isUntinted => hasActivity && moodIndex == null;

  /// A day that has happened and carries nothing. The only state the report is
  /// allowed to draw as an open band.
  bool get isGap => !hasActivity && !isFuture;
}

class ReportSubject {
  const ReportSubject({
    required this.id,
    required this.share,
    this.name,
    this.colorHex,
    this.focusMinutes = 0,
    this.tasksCompleted = 0,
  });

  final String id;

  /// Null when the subject was deleted after the work happened. It still owns
  /// its share of the week; the client draws it as an unlabelled outline and
  /// never names it in copy.
  final String? name;
  final String? colorHex;
  final int focusMinutes;
  final int tasksCompleted;

  /// 0–1.
  final double share;
}

class ReportMoment {
  const ReportMoment({required this.date, required this.title, this.subjectId});

  final DateTime date;
  final String title;
  final String? subjectId;
}

class ReportRecovery {
  const ReportRecovery({
    required this.sessions,
    required this.beforeAvg,
    required this.afterAvg,
    required this.lift,
  });

  final int sessions;
  final double beforeAvg;
  final double afterAvg;

  /// Always > 0 — see `ReportRecoveryDto.lift`.
  final double lift;
}

class ReportLongest {
  const ReportLongest({required this.minutes, required this.date, this.taskTitle});

  final int minutes;
  final DateTime date;
  final String? taskTitle;
}

class ReportPrismSlice {
  const ReportPrismSlice({
    required this.presetId,
    required this.name,
    this.sessions = 0,
    this.share = 0,
  });

  final String presetId;
  final String name;
  final int sessions;

  /// 0–1.
  final double share;
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.shape,
    this.activeDays = 0,
    this.elapsedDays = 7,
    this.daysOnBoard = 0,
    this.subjects = const [],
    this.subjectBasis = SubjectBasis.focusMinutes,
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

  final DateTime weekStart;
  final DateTime weekEnd;

  /// Always seven, Monday first.
  final List<ReportDay> days;
  final WeekShape shape;

  /// The hero numeral: days **this week** that carried work.
  final int activeDays;

  /// Days the week has had so far — 4 on a Thursday, 7 once it is over.
  final int elapsedDays;

  /// Lifetime days on the board. Not headlined anywhere; kept because it is the
  /// only count here that cannot go down.
  final int daysOnBoard;
  final List<ReportSubject> subjects;
  final SubjectBasis subjectBasis;
  final int unattributedFocusMinutes;
  final int unattributedTasksCompleted;
  final ReportMoment? moment;
  final ReportRecovery? recovery;
  final ReportLongest? longestSession;

  /// Minutes held frozen — paused, not lost. The only figure that can make a
  /// started-then-frozen week read as non-empty.
  final int heldMinutes;
  final List<ReportPrismSlice> prismMix;
  final List<int> rhythmWeekdays;
  final int focusMinutes;
  final int focusSessions;
  final int tasksCompleted;

  /// Whether there is anything at all to draw. An empty week still renders —
  /// it is a real week — but the beats that would have nothing to say stay out.
  bool get isEmpty => activeDays == 0;

  /// Share of the week's attention that belongs to no subject. Drawn in the
  /// distribution, never named.
  double get unattributedShare {
    final owned = subjects.fold<double>(0, (n, s) => n + s.share);
    return (1 - owned).clamp(0.0, 1.0);
  }
}
