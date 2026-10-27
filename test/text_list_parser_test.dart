import 'package:aqademiq/services/device_import/text_list_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reminder import → Paste a list. The parser decides which day a pasted line
/// lands on, and a wrong day is worse than none — a task filed on the wrong
/// day is easy to miss — so the conservative cases are pinned as firmly as the
/// helpful ones.
void main() {
  // Tuesday 27 October 2026.
  final today = DateTime(2026, 10, 27);

  ParsedListItem one(String line) {
    final items = parseTextList(line, today: today);
    expect(items, hasLength(1), reason: 'parsing "$line"');
    return items.single;
  }

  group('dates and times are lifted out of the title', () {
    test('a weekday closing the line is the coming one', () {
      final item = one('Essay draft fri');
      expect(item.title, 'Essay draft');
      expect(item.date, DateTime(2026, 10, 30));
      expect(item.hasTime, isFalse);
    });

    test('day/month with a 12-hour time', () {
      final item = one('- Lab report 30/10 5pm');
      expect(item.title, 'Lab report');
      expect(item.date, DateTime(2026, 10, 30));
      expect(item.hour, 17);
      expect(item.minute, 0);
    });

    test('"tomorrow at 7:30pm" with its connecting words', () {
      final item = one('Call home tomorrow at 7:30pm');
      expect(item.title, 'Call home');
      expect(item.date, DateTime(2026, 10, 28));
      expect(item.hour, 19);
      expect(item.minute, 30);
    });

    test('"by Nov 3" takes "by" with it', () {
      final item = one('Submit SOP by Nov 3');
      expect(item.title, 'Submit SOP');
      expect(item.date, DateTime(2026, 11, 3));
    });

    test('ISO date and a 24-hour time', () {
      final item = one('Revise chapter 4 on 2026-11-02 14:00');
      expect(item.title, 'Revise chapter 4');
      expect(item.date, DateTime(2026, 11, 2));
      expect(item.hour, 14);
    });

    test('a day written out with its month', () {
      final item = one('Thesis meeting 3rd December');
      expect(item.title, 'Thesis meeting');
      expect(item.date, DateTime(2026, 12, 3));
    });

    test('"due tmrw 9am"', () {
      final item = one('Physics HW due tmrw 9am');
      expect(item.title, 'Physics HW');
      expect(item.date, DateTime(2026, 10, 28));
      expect(item.hour, 9);
    });

    test('"next mon" is never today', () {
      final item = one('Gym next mon');
      expect(item.title, 'Gym');
      expect(item.date, DateTime(2026, 11, 2));
    });

    test('a bare weekday that is today means today', () {
      expect(one('Pay rent tuesday').date, DateTime(2026, 10, 27));
    });

    test('a short afternoon time without am/pm is the afternoon', () {
      final item = one('Lab 2:30');
      expect(item.hour, 14);
      expect(item.minute, 30);
      expect(item.title, 'Lab');
    });

    test('12pm is noon and 12am is midnight', () {
      expect(one('Lunch 12pm').hour, 12);
      expect(one('Deadline 12am').hour, 0);
    });
  });

  group('the year of a date written without one', () {
    test('a date a few months back means next year', () {
      expect(one('Pay fees 5 Jan').date, DateTime(2027, 1, 5));
    });

    test('a recent date stays this year (it is overdue, not a year away)', () {
      expect(one('Assignment 20/10').date, DateTime(2026, 10, 20));
    });

    test('month/day only when the numbers rule out day/month', () {
      expect(one('Quiz 11/25').date, DateTime(2026, 11, 25));
    });

    test('a date that does not exist is left in the title', () {
      final item = one('Plan 31/11 trip');
      expect(item.date, isNull);
      expect(item.title, 'Plan 31/11 trip');
    });
  });

  group('what is not a date', () {
    test('"SAT prep" is the exam, not Saturday', () {
      final item = one('SAT prep');
      expect(item.date, isNull);
      expect(item.title, 'SAT prep');
    });

    test('a decimal is not a date', () {
      final item = one('Read 2.5 chapters');
      expect(item.date, isNull);
      expect(item.title, 'Read 2.5 chapters');
    });

    test('a fraction is not a date', () {
      final item = one('Read 1/2 of book');
      expect(item.date, isNull);
      expect(item.title, 'Read 1/2 of book');
    });

    test('small numbers are a date once something says so', () {
      final introduced = one('Submit on 3/11 to TA');
      expect(introduced.date, DateTime(2026, 11, 3));
      expect(introduced.title, 'Submit to TA');
      // A number over 12 can only be a day, wherever it sits.
      expect(one('Lab report 30/10 submit online').date, DateTime(2026, 10, 30));
    });

    test('a possessive weekday is part of the title', () {
      final item = one("Exam prep for Monday's quiz");
      expect(item.date, isNull);
      expect(item.title, "Exam prep for Monday's quiz");
    });

    test('a line with no date or time keeps all of its words', () {
      final item = one('Return library books');
      expect(item.title, 'Return library books');
      expect(item.date, isNull);
      expect(item.hasTime, isFalse);
    });
  });

  group('list markers', () {
    test('bullets, numbers and empty checkboxes are stripped', () {
      final items = parseTextList('- One\n• Two\n1. Three\n2) Four\n- [ ] Five\n☐ Six', today: today);
      expect(items.map((i) => i.title), ['One', 'Two', 'Three', 'Four', 'Five', 'Six']);
    });

    test('ticked items and blank lines are skipped', () {
      final items = parseTextList('[x] Done already\n\n   \n✓ Also done\n- [x] And this\nStill to do', today: today);
      expect(items.map((i) => i.title), ['Still to do']);
    });

    test('Windows line endings', () {
      expect(parseTextList('A\r\nB\r\n', today: today).map((i) => i.title), ['A', 'B']);
    });

    test('the list is capped', () {
      final text = List.generate(30, (i) => 'Item $i').join('\n');
      expect(parseTextList(text, today: today, maxItems: 10), hasLength(10));
    });
  });
}
