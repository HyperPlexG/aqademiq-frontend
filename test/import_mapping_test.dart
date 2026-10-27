import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/import_item.dart';
import 'package:aqademiq/services/device_import/import_mapping.dart';
import 'package:aqademiq/services/device_import/text_list_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// How every import source becomes the same item — and so the same task.
void main() {
  final today = DateTime(2026, 10, 27);

  group('phone calendar events', () {
    test('a timed event keeps its time and length, one item per occurrence', () {
      final start = DateTime(2026, 10, 28, 9);
      final item = itemFromDeviceEvent({
        'id': 'EVT-1',
        'title': '  CS F211   Lecture ',
        'start': start.millisecondsSinceEpoch,
        'end': DateTime(2026, 10, 28, 9, 50).millisecondsSinceEpoch,
        'allDay': false,
        'startDay': '2026-10-28',
        'location': 'Room 204',
        'calendarId': 'cal-1',
        'calendarTitle': 'University',
      })!;
      expect(item.externalId, 'EVT-1@${start.millisecondsSinceEpoch}');
      expect(item.title, 'CS F211 Lecture');
      expect(item.date, DateTime(2026, 10, 28));
      expect(item.startTime, start);
      expect(item.durationMin, 50);
      expect(item.note, 'Location: Room 204');
      expect(item.groupTitle, 'University');
      expect(item.dayPart, DayPart.morning);
    });

    test("an all-day event uses the platform's day, not the instant", () {
      // Android stores all-day events at UTC midnight: west of Greenwich the
      // instant reads as the previous evening.
      final item = itemFromDeviceEvent({
        'id': 'EVT-2',
        'title': 'Fest',
        'start': DateTime.utc(2026, 10, 30).millisecondsSinceEpoch,
        'allDay': true,
        'startDay': '2026-10-30',
      })!;
      expect(item.date, DateTime(2026, 10, 30));
      // Keyed by the day, so travelling to another zone does not turn the
      // same all-day event into a new item.
      expect(item.externalId, 'EVT-2@2026-10-30');
      expect(item.startTime, isNull);
      expect(item.durationMin, isNull);
      expect(item.allDay, isTrue);
      expect(item.dayPart, DayPart.anytime);
    });

    test('an event with no title gets a placeholder; one with no id is dropped', () {
      expect(
        itemFromDeviceEvent({'id': 'x', 'start': DateTime(2026, 10, 28, 15).millisecondsSinceEpoch})!.title,
        'Untitled event',
      );
      expect(itemFromDeviceEvent({'title': 'No id', 'start': 0}), isNull);
    });
  });

  group('Apple Reminders', () {
    test('a dated, timed reminder lands on its day at its time', () {
      final due = DateTime(2026, 10, 30, 17);
      final item = itemFromDeviceReminder({
        'id': 'R1',
        'title': 'Submit lab',
        'due': due.millisecondsSinceEpoch,
        'dueHasTime': true,
        'listTitle': 'School',
      }, today: today)!;
      expect(item.date, DateTime(2026, 10, 30));
      expect(item.startTime, due);
      expect(item.placement, ImportPlacement.asScheduled);
      expect(item.dayPart, DayPart.evening);
    });

    test('a date-only reminder has no time', () {
      final item = itemFromDeviceReminder({
        'id': 'R2',
        'title': 'Buy notebook',
        'due': DateTime(2026, 10, 29).millisecondsSinceEpoch,
        'dueHasTime': false,
      }, today: today)!;
      expect(item.date, DateTime(2026, 10, 29));
      expect(item.startTime, isNull);
    });

    test('overdue and undated reminders go on today, without a time', () {
      final overdue = itemFromDeviceReminder({
        'id': 'R3',
        'title': 'Pay fees',
        'due': DateTime(2026, 10, 20, 9).millisecondsSinceEpoch,
        'dueHasTime': true,
      }, today: today)!;
      expect(overdue.date, today);
      expect(overdue.startTime, isNull);
      expect(overdue.placement, ImportPlacement.overdue);

      final undated = itemFromDeviceReminder({'id': 'R4', 'title': 'Call home'}, today: today)!;
      expect(undated.date, today);
      expect(undated.placement, ImportPlacement.undated);
    });
  });

  group('pasted lines', () {
    test('the id is the title and the written date, so pasting twice is recognised', () {
      final a = itemFromListLine(ParsedListItem(title: 'Essay draft', date: DateTime(2026, 10, 30)), today: today);
      final b = itemFromListLine(
        ParsedListItem(title: 'essay   DRAFT', date: DateTime(2026, 10, 30)),
        today: DateTime(2026, 10, 28),
      );
      expect(a.externalId, 'essay draft@2026-10-30');
      expect(b.externalId, a.externalId);
    });

    test('an undated line is keyed as undated, not by the day it was pasted', () {
      final monday = itemFromListLine(const ParsedListItem(title: 'Return books'), today: DateTime(2026, 10, 26));
      final friday = itemFromListLine(const ParsedListItem(title: 'Return books'), today: DateTime(2026, 10, 30));
      expect(monday.externalId, 'return books@undated');
      expect(friday.externalId, monday.externalId);
      expect(friday.date, DateTime(2026, 10, 30));
    });

    test('a time on an undated line puts it at that time today', () {
      final item = itemFromListLine(const ParsedListItem(title: 'Call home', hour: 19, minute: 30), today: today);
      expect(item.startTime, DateTime(2026, 10, 27, 19, 30));
    });

    test('an overdue line goes on today without its old time', () {
      final item = itemFromListLine(
        ParsedListItem(title: 'Lab', date: DateTime(2026, 10, 20), hour: 9),
        today: today,
      );
      expect(item.date, today);
      expect(item.startTime, isNull);
      expect(item.placement, ImportPlacement.overdue);
    });
  });

  group('helpers', () {
    test('a duration stops at midnight', () {
      final start = DateTime(2026, 10, 30, 22);
      expect(durationMinutes(start, DateTime(2026, 11, 1, 12)), 120);
      expect(durationMinutes(start, start), isNull);
      expect(durationMinutes(start, null), isNull);
    });

    test('the note puts the place first and is kept short', () {
      expect(buildImportNote(notes: 'Bring calculator', location: 'Hall B'), 'Location: Hall B\n\nBring calculator');
      expect(buildImportNote(notes: '  '), isNull);
      expect(buildImportNote(notes: 'x' * 5000)!.length, maxImportNoteLength);
    });

    test('items sort by day, then untimed first, then time, then title', () {
      ImportItem at(String title, DateTime date, [DateTime? start]) =>
          ImportItem(externalId: title, title: title, date: date, startTime: start);
      final sorted = sortImportItems([
        at('c', DateTime(2026, 10, 28), DateTime(2026, 10, 28, 9)),
        at('b', DateTime(2026, 10, 28)),
        at('a', DateTime(2026, 10, 27), DateTime(2026, 10, 27, 15)),
        at('d', DateTime(2026, 10, 28), DateTime(2026, 10, 28, 8)),
      ]);
      expect(sorted.map((i) => i.title), ['a', 'b', 'd', 'c']);
    });

    test('long external ids fit the server and stay distinct and stable', () {
      final long = 'x' * 1000;
      final monday = clipExternalId('$long@1793174400000');
      final wednesday = clipExternalId('$long@1793347200000');
      expect(monday.length, lessThanOrEqualTo(maxExternalIdLength));
      expect(monday, endsWith('@1793174400000'));
      expect(monday, isNot(wednesday));
      expect(clipExternalId('$long@1793174400000'), monday);
      expect(clipExternalId(long).length, lessThanOrEqualTo(maxExternalIdLength));
      expect(clipExternalId('short@1'), 'short@1');
    });
  });
}
