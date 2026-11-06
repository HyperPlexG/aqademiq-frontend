// "When you thawed" — the one weekly-report beat the server cannot fill.
//
// App freeze's thaw history never leaves the phone, so the report lays it on
// its own week here. Two things have to be exactly right, and both fail
// silently: which records count as a thaw, and which day of the report's week
// each one lands on. A beat that drew a stand-down as a thaw, or put Sunday
// night's thaw on Monday, would be telling someone something false about a
// week they lived.

import 'package:aqademiq/data/models/weekly_report.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/report/report_copy.dart';
import 'package:aqademiq/features/report/report_thaws.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime(2026, 8, 31);

List<ReportDay> _week({int elapsed = 7}) => [
      for (var i = 0; i < 7; i++)
        ReportDay(
          date: _monday.add(Duration(days: i)),
          weekday: i + 1,
          hasActivity: false,
          isFuture: i >= elapsed,
        ),
    ];

ThawRecord _thaw(int day, {int hour = 12, int minutes = 5}) =>
    ThawRecord(at: DateTime(2026, 8, 31 + day, hour), minutes: minutes, target: 'com.example.app');

void main() {
  test('counts each thaw on the calendar day it happened, Monday first', () {
    final counts = thawsByDay(_week(), [
      _thaw(1, hour: 9),
      _thaw(1, hour: 23),
      _thaw(3),
      _thaw(6, hour: 1),
    ]);
    expect(counts, [0, 2, 0, 1, 0, 0, 1]);
  });

  test('"Thaw everything" is a stand-down, not a thaw', () {
    final counts = thawsByDay(_week(), [
      ThawRecord(at: DateTime(2026, 9, 2, 10), minutes: 0, target: ThawGrant.allApps),
    ]);
    expect(counts, everyElement(0));
  });

  test('thaws outside the week belong to another week', () {
    final counts = thawsByDay(_week(), [
      _thaw(-1, hour: 23), // the Sunday before
      _thaw(7, hour: 0), // the Monday after
    ]);
    expect(counts, everyElement(0));
  });

  test('a day still to come has nothing on it, and that is not a gap', () {
    // Opened on a Wednesday: Thursday onwards cannot hold a thaw yet.
    final counts = thawsByDay(_week(elapsed: 3), [_thaw(2)]);
    expect(counts, [0, 0, 1, 0, 0, 0, 0]);
  });

  test('the beat shows only when App freeze is set up and the week has a thaw', () {
    expect(showThawedBeat(freezeSetUp: true, thaws: const [0, 1, 0, 0, 0, 0, 0]), isTrue);
    expect(showThawedBeat(freezeSetUp: true, thaws: const [0, 0, 0, 0, 0, 0, 0]), isFalse);
    expect(showThawedBeat(freezeSetUp: false, thaws: const [0, 3, 0, 0, 0, 0, 0]), isFalse);
    expect(showThawedBeat(freezeSetUp: true, thaws: const []), isFalse);
  });

  test('a screen reader hears the drawing, and nothing about a day without one', () {
    expect(ReportCopy.thawedDay('Tuesday', 0), 'Tuesday');
    expect(ReportCopy.thawedDay('Tuesday', 1), 'Tuesday, one thaw');
    expect(ReportCopy.thawedDay('Tuesday', 3), 'Tuesday, 3 thaws');
  });

  test('the week reads as dates, across a month too', () {
    expect(ReportCopy.weekRange(DateTime(2026, 6, 22), DateTime(2026, 6, 28)), 'Jun 22 – 28');
    expect(ReportCopy.weekRange(DateTime(2026, 6, 29), DateTime(2026, 7, 5)), 'Jun 29 – Jul 5');
  });
}
