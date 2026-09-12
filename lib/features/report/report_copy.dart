/// Every sentence the weekly report can say, in one file.
///
/// The report's safety contract is a vocabulary rule, and a vocabulary rule is
/// only worth what it can be checked against. Copy scattered across a dozen
/// widgets cannot be checked; copy in one file with a banned list beside it can,
/// and `test/report_copy_test.dart` does exactly that on every run.
///
/// Two rules shape all of it:
///
///  * **Describe the week, never the person.** "The weight sat early" is a
///    finding about a distribution. "You started strong" is a claim about
///    someone, and the same sentence read after a hard week becomes a
///    comparison to a version of themselves they did not manage to be.
///  * **The register does not change with the week.** A full week and an empty
///    one are narrated in the same voice. Warming the tone for a bad week is
///    how a report tells someone it noticed.
library;

import '../../data/models/weekly_report.dart';

/// Metric shapes and words that must never render, kept next to the copy they
/// constrain.
///
/// This list is not documentation — `report_copy_test.dart` asserts that no
/// string this file can produce contains any of it, and that no sentence
/// contains a digit-slash-digit denominator. A target the student can fall
/// short of is the thing the whole design is built to avoid, and denominators
/// are how targets get in.
///
/// `only` is on the list for one reason: it is the word that turns a count into
/// a shortfall ("only three days"). That costs us the natural phrasing in a
/// couple of places — the share note reads "Just your shape" rather than "Your
/// shape only" — and the trade is worth it, because the lint is worthless the
/// first time it gets an exception.
const List<String> kReportBannedWords = [
  'streak',
  'goal',
  'target',
  'consistency',
  'productive',
  'wasted',
  'reserve',
  'low',
  'behind',
  'missed',
  'unbroken',
  'average',
  'percent',
  'score',
  'rank',
  'should',
  'failed',
  'only',
];

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// 1 = Monday … 7 = Sunday. Out-of-range input returns an empty string rather
/// than throwing inside a screen the student is already looking at.
String weekdayName(int weekday) =>
    (weekday >= 1 && weekday <= 7) ? _weekdayNames[weekday - 1] : '';

abstract final class ReportCopy {
  // ---- the way in, from the Stats tab ------------------------------------

  static const String entryEyebrow = 'YOUR WEEK';
  static const String coreName = 'The Core';
  static const String entryTagline = 'Seven days, drilled and read.';

  // ---- beat 1 — the core freezes in --------------------------------------

  static const String drilling = 'Drilling your week…';

  // ---- beat 2 — the shape of the week ------------------------------------

  static const String shapeLabel = 'THE SHAPE OF THE WEEK';

  /// One sentence about the *shape*, before a single number appears anywhere.
  ///
  /// Every one of these is a statement about a distribution. None is better or
  /// worse than another, and none can be read as a grade.
  static String shape(WeekShape shape) => switch (shape) {
        WeekShape.empty => 'An open core, all the way down.',
        WeekShape.single => 'One band, and a lot of open core.',
        WeekShape.steady => 'Layers right through the week.',
        WeekShape.frontLoaded => 'A thick start, then open core.',
        WeekShape.backLoaded => 'Open core, then it gathered.',
        WeekShape.clustered => 'A quiet start, then days that held.',
        WeekShape.scattered => 'Thin bands, spread out.',
      };

  // ---- beat 3 — the core itself ------------------------------------------

  static const String coreCaption =
      'Each band is a day, Monday at the top. Tint is that day’s mood.';

  /// Said only when at least one band is empty, so a full week is not handed an
  /// explanation of a thing it does not contain. The named day makes the rule
  /// concrete instead of abstract.
  static String gapCaption(String dayName) =>
      '$dayName has nothing logged, so it stays an open band.';

  /// The generic form, for a week whose gaps are not worth singling out.
  static const String gapCaptionPlain =
      'A day with nothing logged stays an open band.';

  // ---- beat 4 — one thing that happened ----------------------------------

  static const String momentTitle = 'ONE THING THAT HAPPENED';

  /// A named task on a named day, never an aggregate.
  static String moment(ReportMoment m) =>
      '${weekdayName(m.date.weekday)}, you finished “${m.title}”.';

  /// The chip under it: the task, and where it sat.
  static String momentWhere(ReportMoment m, String? subjectName) {
    final day = weekdayName(m.date.weekday);
    return subjectName == null || subjectName.isEmpty ? day : '$subjectName · $day';
  }

  /// A week with nothing completed still gets a concrete line, reaching for the
  /// smallest true thing rather than skipping the beat.
  static String smallestTrueThing(ReportDay day) =>
      '${weekdayName(day.weekday)}, you opened the app and put something down. That’s on the board.';

  // ---- beat 5 — the one numeral ------------------------------------------

  static const String heroLabel = 'DAYS ON THE BOARD';

  // ---- beat 6 — where attention went -------------------------------------

  static const String attentionTitle = 'WHERE ATTENTION WENT';

  /// Names the subject that took the most, and explains the drawing. Never
  /// ranks the rest, and never names a subject that got nothing.
  static String attentionCaption(String? topName) => topName == null || topName.isEmpty
      ? 'The crisper the cube, the more of your attention it held.'
      : '$topName took the most of your week. The crisper the cube, the more of your attention it held.';

  // ---- beat 7 — what the week gave back ----------------------------------

  static const String recoveryTitle = 'WHAT THE WEEK GAVE BACK';

  /// Renders only when it points positive, which is enforced server-side by the
  /// number simply not existing otherwise.
  static String recovery(ReportRecovery r) => r.sessions == 1
      ? 'You finished your session feeling better than you started it.'
      : 'You finished most sessions feeling better than you started them.';

  static const String goingIn = 'GOING IN';
  static const String comingOut = 'COMING OUT';

  // ---- the quieter cards -------------------------------------------------

  static const String longestTitle = 'YOUR LONGEST STRETCH';
  static const String heldTitle = 'HELD TIME COUNTS';
  static const String rhythmTitle = 'YOUR RHYTHM';
  static const String prismTitle = 'WHAT THE WEEK SOUNDED LIKE';

  /// Length and the task, never the word this file bans for it: describing a
  /// stretch as unbroken makes freezing a flaw, and freezing is the product.
  static String longest(ReportLongest l) {
    final where = l.taskTitle;
    final when = weekdayName(l.date.weekday);
    if (where == null || where.isEmpty) return '$when · ${minutes(l.minutes)}';
    return '$when · ${minutes(l.minutes)} on “$where”';
  }

  /// Frozen minutes reported as a kept quantity. The one line that makes a
  /// started-then-frozen week read as non-empty.
  static String held(int mins) => '${minutes(mins)} held frozen, and kept.';

  /// Names the weekdays that reliably carry work — never the thin ones, and
  /// never a count of weeks.
  static String rhythm(List<int> weekdays) {
    final names = weekdays.map(weekdayName).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return '';
    final plural = names.map((n) => '${n}s').toList();
    if (plural.length == 1) return '${plural.first} carry your work.';
    final last = plural.removeLast();
    return '${plural.join(', ')} and $last carry your work.';
  }

  // ---- beat 8 — the landing ----------------------------------------------

  static const String closing =
      'One small thing for next week — or just tomorrow’s check-in, if that’s the size that fits.';

  /// The empty-week landing. Same register, nothing asked for.
  static const String closingEmpty =
      'Next week starts whenever you do. Tomorrow’s check-in is enough to begin one.';

  static const String suggestionTitle = 'Tomorrow’s check-in';
  static const String suggestionSub = 'Two taps, in the morning.';
  static const String keepIt = 'Keep it';
  static const String notThisTime = 'Not this time';

  // ---- sharing -----------------------------------------------------------

  static const String shareLabel = 'Share the shape';

  /// "Just your shape" rather than "your shape only" — see [kReportBannedWords].
  static const String sharePrivacy =
      'Just your shape. Nothing about how you felt is in this image.';
  static const String shareAction = 'Share';
  static const String shareBrand = 'Aqademiq';

  // ---- the off switch, and what the report never does --------------------

  static const String settingsTitle = 'Weekly report';
  static const String settingsToggle = 'Show me The Core';
  static const String settingsToggleNote =
      'One tap turns it off, immediately. We won’t ask again.';
  static const String neverDoesTitle = 'What it never does';

  static const String neverNotify = 'Notify you';
  static const String neverNotifySub = 'It waits in the tab, the same way every week.';
  static const String neverBackBrowse = 'Open on a past week';
  static const String neverBackBrowseSub = 'The current week, never an older one.';
  static const String neverShowWriting = 'Show what you wrote';
  static const String neverShowWritingSub = 'Never shown, never exported.';

  // ---- a bad season, not a bad week --------------------------------------

  /// Shown at most once a month after several consecutive weeks in the lowest
  /// read. Plain product voice, dismissible, and outside the story — Ada does
  /// not comment on it, because a cartoon mascot diagnosing a run of hard weeks
  /// is out of its depth.
  static const String supportBanner =
      'Support resources are available any time, if you’d like them.';
  static const String supportAction = 'View';

  // ---- shared helpers ----------------------------------------------------

  static const String loadFailed =
      'Your week is here, the report just could not reach it.';
  static const String retry = 'Try again';

  /// `48m`, `1h 12m`. Never a decimal — a fractional hour reads as a
  /// measurement of the person rather than a length of time.
  static String minutes(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
