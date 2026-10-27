import 'package:aqademiq/services/device_import/ics_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Calendar import → .ics file / calendar link. Times are compared in UTC so
/// the tests pass in any timezone the suite runs in.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  String cal(String body) => 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n$body\r\nEND:VCALENDAR\r\n';

  List<DateTime> startsUtc(List<IcsOccurrence> list) => [for (final o in list) o.start.toUtc()];

  test('a single timed event, with its text decoded', () {
    final c = parseIcs(
      cal(
        'X-WR-CALNAME:CS Timetable\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:abc@test\r\n'
        'DTSTART:20261028T090000Z\r\n'
        'DTEND:20261028T095000Z\r\n'
        'SUMMARY:CS F211 Lecture\r\n'
        'LOCATION:Room 204\r\n'
        r'DESCRIPTION:Bring laptop\, charger\nChapter 3' '\r\n'
        'END:VEVENT',
      ),
    );
    expect(c.name, 'CS Timetable');
    final list = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 3));
    expect(list, hasLength(1));
    final o = list.single;
    expect(o.title, 'CS F211 Lecture');
    expect(o.start.toUtc(), DateTime.utc(2026, 10, 28, 9));
    expect(o.end!.difference(o.start), const Duration(minutes: 50));
    expect(o.allDay, isFalse);
    expect(o.location, 'Room 204');
    expect(o.description, 'Bring laptop, charger\nChapter 3');
    expect(o.uid, 'abc@test');
    expect(o.key, '${DateTime.utc(2026, 10, 28, 9).millisecondsSinceEpoch}');
  });

  test('TZID is honoured — 09:00 in Dubai is 05:00 UTC, not 09:00', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:tz@test\r\n'
        'DTSTART;TZID=Asia/Dubai:20261028T090000\r\n'
        'DTEND;TZID=Asia/Dubai:20261028T100000\r\n'
        'SUMMARY:Maths\r\n'
        'END:VEVENT',
      ),
    );
    final o = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 3)).single;
    expect(o.start.toUtc(), DateTime.utc(2026, 10, 28, 5));
    expect(o.end!.difference(o.start), const Duration(hours: 1));
  });

  test("Outlook's Windows zone names are understood", () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:win@test\r\n'
        'DTSTART;TZID="Arabian Standard Time":20261028T090000\r\n'
        'SUMMARY:Physics\r\n'
        'END:VEVENT',
      ),
    );
    final o = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 3)).single;
    expect(o.start.toUtc(), DateTime.utc(2026, 10, 28, 5));
  });

  test('a weekly class is expanded, with COUNT and EXDATE respected', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:weekly@test\r\n'
        'DTSTART;TZID=Asia/Dubai:20261005T090000\r\n'
        'DTEND;TZID=Asia/Dubai:20261005T100000\r\n'
        'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6\r\n'
        'EXDATE;TZID=Asia/Dubai:20261012T090000\r\n'
        'SUMMARY:Maths\r\n'
        'END:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10), DateTime.utc(2026, 11));
    expect(startsUtc(list), [
      DateTime.utc(2026, 10, 5, 5),
      DateTime.utc(2026, 10, 7, 5),
      // 12 Oct is excluded; COUNT still counts it.
      DateTime.utc(2026, 10, 14, 5),
      DateTime.utc(2026, 10, 19, 5),
      DateTime.utc(2026, 10, 21, 5),
    ]);
    // Each meeting is its own item.
    expect(list.map((o) => o.key).toSet(), hasLength(5));
  });

  test('a timetable that began years ago still reaches this week', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:old@test\r\n'
        'DTSTART;TZID=Asia/Dubai:20240101T090000\r\n'
        'RRULE:FREQ=WEEKLY\r\n'
        'SUMMARY:Seminar\r\n'
        'END:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10, 26), DateTime.utc(2026, 11, 2));
    expect(startsUtc(list), [DateTime.utc(2026, 10, 26, 5)]);
  });

  test('a moved occurrence replaces the original, and cancelled events are dropped', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:daily@test\r\n'
        'DTSTART:20261026T080000Z\r\n'
        'DTEND:20261026T083000Z\r\n'
        'RRULE:FREQ=DAILY;UNTIL=20261029T235959Z\r\n'
        'SUMMARY:Standup\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:daily@test\r\n'
        'RECURRENCE-ID:20261027T080000Z\r\n'
        'DTSTART:20261027T100000Z\r\n'
        'DTEND:20261027T103000Z\r\n'
        'SUMMARY:Standup (moved)\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:gone@test\r\n'
        'DTSTART:20261028T150000Z\r\n'
        'STATUS:CANCELLED\r\n'
        'SUMMARY:Cancelled thing\r\n'
        'END:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10, 26), DateTime.utc(2026, 11, 2));
    expect(list.map((o) => o.title), ['Standup', 'Standup (moved)', 'Standup', 'Standup']);
    expect(startsUtc(list), [
      DateTime.utc(2026, 10, 26, 8),
      DateTime.utc(2026, 10, 27, 10),
      DateTime.utc(2026, 10, 28, 8),
      DateTime.utc(2026, 10, 29, 8),
    ]);
  });

  test('a weekly class keeps its local time across a DST change', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:ny@test\r\n'
        'DTSTART;TZID=America/New_York:20261026T090000\r\n'
        'RRULE:FREQ=WEEKLY;BYDAY=MO\r\n'
        'SUMMARY:NY class\r\n'
        'END:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10, 25), DateTime.utc(2026, 11, 10));
    // US clocks go back on 1 Nov 2026: 09:00 EDT is 13:00Z, 09:00 EST 14:00Z.
    expect(startsUtc(list), [
      DateTime.utc(2026, 10, 26, 13),
      DateTime.utc(2026, 11, 2, 14),
      DateTime.utc(2026, 11, 9, 14),
    ]);
  });

  test('every other week until a date', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:int@test\r\n'
        'DTSTART:20261001T100000Z\r\n'
        'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TH;UNTIL=20261130\r\n'
        'SUMMARY:Fortnightly lab\r\n'
        'END:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10), DateTime.utc(2027));
    expect(startsUtc(list), [
      DateTime.utc(2026, 10, 1, 10),
      DateTime.utc(2026, 10, 15, 10),
      DateTime.utc(2026, 10, 29, 10),
      DateTime.utc(2026, 11, 12, 10),
      DateTime.utc(2026, 11, 26, 10),
    ]);
  });

  test('monthly on the last Friday', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:monthly@test\r\n'
        'DTSTART:20261030T140000Z\r\n'
        'RRULE:FREQ=MONTHLY;BYDAY=-1FR;COUNT=3\r\n'
        'SUMMARY:Department meeting\r\n'
        'END:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10), DateTime.utc(2027, 2));
    expect(startsUtc(list), [
      DateTime.utc(2026, 10, 30, 14),
      DateTime.utc(2026, 11, 27, 14),
      DateTime.utc(2026, 12, 25, 14),
    ]);
  });

  test('an all-day event keeps its day and length', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:fest@test\r\n'
        'DTSTART;VALUE=DATE:20261030\r\n'
        'DTEND;VALUE=DATE:20261101\r\n'
        'SUMMARY:Fest\r\n'
        'END:VEVENT',
      ),
    );
    final o = c.occurrencesBetween(DateTime(2026, 10, 27), DateTime(2026, 11, 3)).single;
    expect(o.allDay, isTrue);
    expect(o.start, DateTime(2026, 10, 30));
    expect(o.end, DateTime(2026, 11));
    expect(o.key, '20261030');
  });

  test("an alarm's description does not replace the event's", () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:alarm@test\r\n'
        'DTSTART:20261029T120000Z\r\n'
        'SUMMARY:Quiz\r\n'
        'DESCRIPTION:Real description\r\n'
        'BEGIN:VALARM\r\n'
        'ACTION:DISPLAY\r\n'
        'DESCRIPTION:Reminder\r\n'
        'TRIGGER:-PT15M\r\n'
        'END:VALARM\r\n'
        'END:VEVENT',
      ),
    );
    final o = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 3)).single;
    expect(o.description, 'Real description');
    expect(o.end, isNull);
  });

  test('folded lines are joined, and a missing title gets a placeholder', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\n'
        'UID:fold@test\r\n'
        'DTSTART:20261029T120000Z\r\n'
        'DESCRIPTION:Very long\r\n  description\r\n'
        'END:VEVENT',
      ),
    );
    final o = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 3)).single;
    expect(o.description, 'Very long description');
    expect(o.title, 'Untitled event');
  });

  test('only occurrences inside the window come back, sorted', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\nUID:b\r\nDTSTART:20261030T100000Z\r\nSUMMARY:Later\r\nEND:VEVENT\r\n'
        'BEGIN:VEVENT\r\nUID:a\r\nDTSTART:20261028T100000Z\r\nSUMMARY:Sooner\r\nEND:VEVENT\r\n'
        'BEGIN:VEVENT\r\nUID:old\r\nDTSTART:20250101T100000Z\r\nSUMMARY:Last year\r\nEND:VEVENT\r\n'
        'BEGIN:VEVENT\r\nUID:far\r\nDTSTART:20270601T100000Z\r\nSUMMARY:Next summer\r\nEND:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 27));
    expect(list.map((o) => o.title), ['Sooner', 'Later']);
    expect(c.eventCount, 4);
  });

  test('a limit keeps the earliest occurrences, not the first in the file', () {
    final c = parseIcs(
      cal(
        'BEGIN:VEVENT\r\nUID:late\r\nDTSTART:20261030T100000Z\r\nSUMMARY:Later\r\nEND:VEVENT\r\n'
        'BEGIN:VEVENT\r\nUID:early\r\nDTSTART:20261028T100000Z\r\nSUMMARY:Sooner\r\nEND:VEVENT',
      ),
    );
    final list = c.occurrencesBetween(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 11, 27), limit: 1);
    expect(list.map((o) => o.title), ['Sooner']);
  });

  test('text that is not a calendar is refused with a readable message', () {
    expect(() => parseIcs('<html>Sign in to continue</html>'), throwsA(isA<IcsParseException>()));
  });
}
