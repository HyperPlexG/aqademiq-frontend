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

/// Metric shapes that must never render, kept next to the copy they constrain.
///
/// This list is not documentation — `report_copy_test.dart` asserts that no
/// string this file can produce contains any of it, and that no sentence
/// contains a digit-slash-digit denominator. A target the student can fall
/// short of is the thing the whole design is built to avoid, and denominators
/// are how targets get in.
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
  /// Beat 2 — the shape of the week, before a single number appears.
  ///
  /// Every one of these is a statement about a distribution. None of them is
  /// better or worse than another, and none can be read as a grade.
  static String shape(WeekShape shape) => switch (shape) {
        WeekShape.empty => 'A clear core this week.',
        WeekShape.single => 'One day carried this week.',
        WeekShape.steady => 'Spread right across the week.',
        WeekShape.frontLoaded => 'The weight sat early this week.',
        WeekShape.backLoaded => 'The week gathered towards the end.',
        WeekShape.clustered => 'A quiet start, then a run that held.',
        WeekShape.scattered => 'A week in patches.',
      };

  /// Beat 5 — the label under the one numeral. A count of things that happened,
  /// never a rate, and with nothing to divide it by.
  static const String heroLabel = 'DAYS ON THE BOARD';

  /// Beat 1 — what the core is, said once.
  static const String coreCaption =
      'Each band is a day, Monday at the top. Tint is that day’s mood.';

  /// Said only when at least one band is empty, so a full week is not handed an
  /// explanation of a thing it does not contain.
  static const String gapCaption = 'A day with nothing logged is an empty band.';

  /// Beat 4 — one concrete thing that happened. A named task on a named day,
  /// never an aggregate.
  static String moment(ReportMoment m) =>
      '${weekdayName(m.date.weekday)}, you finished “${m.title}”.';

  /// Card labels. They live here rather than inline in the screen for one
  /// reason: `report_copy_test.dart` scans this file, and a label written at
  /// its call site is a sentence the lint cannot see.
  static const String attentionTitle = 'Where attention went';
  static const String momentTitle = 'One thing that happened';
  static const String recoveryTitle = 'What the week gave back';
  static const String longestTitle = 'Your longest stretch';
  static const String heldTitle = 'Held time counts';
  static const String rhythmTitle = 'Your rhythm';
  static const String prismTitle = 'What the week sounded like';

  /// The section's own name, and the way in from the Stats tab.
  static const String coreTitle = 'THE CORE';
  static const String entryTitle = 'This week’s core';
  static const String entrySub = 'Seven days, drilled and read back';

  /// Shown while the core is still being drilled.
  static const String drilling = 'Drilling';

  /// A subject deleted after the work happened. Named as absent rather than
  /// invented, and never as something the student neglected.
  static const String namelessSubject = 'A subject that is no longer here';

  /// The failure state. It says the week exists and the fetch did not, because
  /// "could not load your week" reads as the week being the thing that is gone.
  static const String loadFailed =
      'Your week is here, the report just could not reach it.';
  static const String retry = 'Try again';

  /// Beat 7 — the recovery read. Renders only when it points positive, which is
  /// enforced server-side by the number simply not existing otherwise.
  static String recovery(ReportRecovery r) => r.sessions == 1
      ? 'One session ended lighter than it started.'
      : '${_count(r.sessions)} sessions ended lighter than they started.';

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

  /// Beat 8 — the landing. Sized so that refusing it would feel absurd.
  static const String closing =
      'One small thing for next week — or just tomorrow’s check-in, if that’s the size that fits.';

  /// The empty-week landing. Same register, nothing asked for.
  static const String closingEmpty =
      'Next week starts whenever you do. Tomorrow’s check-in is enough to begin one.';

  /// Sharing sits beside the landing, never as the finale — and carries the
  /// activity shape only, never a mood.
  static const String shareLabel = 'Share the shape';
  static const String shareNote = 'Shares the shape of your week. Mood stays here.';

  /// `48m`, `1h 12m`. Never a decimal — a fractional hour reads as a
  /// measurement of the person rather than a length of time.
  static String minutes(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  static String _count(int n) => switch (n) {
        2 => 'Two',
        3 => 'Three',
        4 => 'Four',
        5 => 'Five',
        6 => 'Six',
        7 => 'Seven',
        _ => '$n',
      };
}
