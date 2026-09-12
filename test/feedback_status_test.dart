// The feedback status vocabulary has to match the server exactly.
//
// It drifted once and the failure was silent in both directions. This enum
// still carried an older set (open / completed / acknowledged / exists_already)
// while the board had long since shipped with under_review / planned /
// in_progress / shipped / declined. Because `fromWire` falls back instead of
// failing, THREE live statuses — under_review, shipped and declined — all
// landed on the single value `open`.
//
// Two things broke, and neither looked like a mapping bug:
//
//   * The filter pills compare `statusFilter == status.value`, so tapping any
//     one of those three lit up all three at once.
//   * The filter then sent `status=open`, a key the server has never defined,
//     so a board holding five shipped posts answered "no suggestions match" —
//     which read as "marking things shipped in the admin console did not work",
//     when the console had in fact written six correct audit rows.
//
// The first test is the one that matters: distinctness. A fallback that quietly
// merges statuses is what turns a stale enum into an invisible bug.

import 'package:aqademiq/data/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `key` column of `feedback_statuses` in production, in sort_order.
/// Update this list ONLY together with a backend migration.
const backendStatusKeys = <String>[
  'under_review',
  'planned',
  'in_progress',
  'shipped',
  'declined',
];

void main() {
  test('every backend key maps to a DISTINCT status', () {
    final mapped = backendStatusKeys.map(FeedbackStatusX.fromWire).toList();
    expect(
      mapped.toSet().length,
      backendStatusKeys.length,
      reason: 'two or more server statuses collapsed onto one enum value — '
          'filter pills will highlight together and the filter will query a '
          'status the server does not have',
    );
  });

  test('each key maps to the status it names', () {
    expect(FeedbackStatusX.fromWire('under_review'), FeedbackStatus.underReview);
    expect(FeedbackStatusX.fromWire('planned'), FeedbackStatus.planned);
    expect(FeedbackStatusX.fromWire('in_progress'), FeedbackStatus.inProgress);
    expect(FeedbackStatusX.fromWire('shipped'), FeedbackStatus.shipped);
    expect(FeedbackStatusX.fromWire('declined'), FeedbackStatus.declined);
  });

  test('the enum covers the backend set exactly — no more, no less', () {
    // A value with no server key would be unreachable; a key with no value
    // would fall through to the default and re-create the collapse.
    expect(
      FeedbackStatus.values.map((s) => s.wire).toSet(),
      backendStatusKeys.toSet(),
    );
  });

  test('wire round-trips for every status', () {
    for (final s in FeedbackStatus.values) {
      expect(FeedbackStatusX.fromWire(s.wire), s, reason: 'round trip for $s');
    }
  });

  test('the two underscored keys are not emitted as camelCase', () {
    // `name` would give "underReview"/"inProgress", which the server rejects.
    expect(FeedbackStatus.underReview.wire, 'under_review');
    expect(FeedbackStatus.inProgress.wire, 'in_progress');
  });

  test('an unknown key falls back without throwing', () {
    // Rendering must survive a status this build has never heard of; the
    // distinctness test above is what stops the fallback hiding a real one.
    expect(FeedbackStatusX.fromWire('some_future_status'),
        FeedbackStatus.underReview);
    expect(FeedbackStatusX.fromWire(null), FeedbackStatus.underReview);
  });

  test('the fallback equals the database default', () {
    // feedback_posts.status_key defaults to 'under_review', so a post created
    // with no status shows the same thing the server thinks it is.
    expect(FeedbackStatusX.fromWire(null).wire, 'under_review');
  });
}
