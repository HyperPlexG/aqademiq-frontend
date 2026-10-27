import 'package:meta/meta.dart';

// Reminder import → "Paste a list". Android has no reminders store other apps
// can read (Samsung Reminder, Google Keep and Todoist each keep their own), so
// the way in is the clipboard: copy the list, paste it, one reminder per line.
//
// A line may carry a date and a time the way people actually write them —
// "Essay draft fri", "Lab report 30/10 5pm", "Pay fees by Nov 3",
// "Call home tmrw 7:30pm" — and they are lifted out of the title. Pure, so it
// is unit tested directly (test/text_list_parser_test.dart).
//
// Deliberately conservative: a wrong date is worse than no date, because a
// task filed on the wrong day is easy to miss. So "SAT prep" stays a title
// (three-letter weekdays only count after "on"/"by"/"next"… or at the very end
// of the line), "Read 2.5 chapters" is not the 2nd of May (dotted dates need a
// year), and day/month order is the one used in the UAE and India unless the
// numbers rule it out.

/// One line of a pasted list.
@immutable
class ParsedListItem {
  const ParsedListItem({
    required this.title,
    this.date,
    this.hour,
    this.minute = 0,
  });

  final String title;

  /// The day written on the line (date only), or null.
  final DateTime? date;

  /// The time written on the line (24h), or null.
  final int? hour;
  final int minute;

  bool get hasTime => hour != null;
}

const _monthNames = <String, int>{
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sept': 9,
  'sep': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
};

// Longest spellings first so "september" is not read as "sep" + "tember".
const _monthPattern = 'january|february|march|april|may|june|july|august|september|'
    'october|november|december|sept|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec';

const _weekdayNames = <String, int>{
  'monday': DateTime.monday,
  'mon': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'tues': DateTime.tuesday,
  'tue': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'wed': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'thurs': DateTime.thursday,
  'thur': DateTime.thursday,
  'thu': DateTime.thursday,
  'friday': DateTime.friday,
  'fri': DateTime.friday,
  'saturday': DateTime.saturday,
  'sat': DateTime.saturday,
  'sunday': DateTime.sunday,
  'sun': DateTime.sunday,
};

final _doneMark = RegExp(r'^\s*(?:[-*•]\s*)?(?:\[[xX✓✔]\]|☑|✅|✔|✓)');

/// Any run of list markers: "- ", "• ", "[ ] ", "☐ ", "1. ", "2) ", "- [ ] ".
final _bullet = RegExp(r'^\s*(?:(?:[-*•◦▪‣·–—>]+|\[\s?\]|☐|⬜)\s*|\d{1,3}[.)]\s+)+');

final _time12 = RegExp(
  r'(?:\bat\s+|@\s*)?\b(1[0-2]|0?[1-9])(?:[:.]([0-5]\d))?\s*([ap])\.?m\b\.?',
  caseSensitive: false,
);
final _time24 = RegExp(r'(?:\bat\s+|@\s*)?\b([01]?\d|2[0-3]):([0-5]\d)\b', caseSensitive: false);

final _isoDate = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
final _slashDate = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?\b');
final _dotDate = RegExp(r'\b(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})\b');
final _dayMonth = RegExp(
  [r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(', _monthPattern, r')\b\.?(?:,?\s+(\d{4})\b)?'].join(),
  caseSensitive: false,
);
final _monthDay = RegExp(
  [r'\b(', _monthPattern, r')\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b(?:,?\s+(\d{4})\b)?'].join(),
  caseSensitive: false,
);
final _relative = RegExp(r'\b(today|tonight|tomorrow|tomorow|tommorow|tmrw|tmr)\b', caseSensitive: false);
final _weekdayFull = RegExp(
  r"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b(?!['’]s)",
  caseSensitive: false,
);
final _weekdayShort = RegExp(r"\b(mon|tues|tue|wed|thurs|thur|thu|fri|sat|sun)\b(?!['’]s)\.?", caseSensitive: false);

/// Words that introduce a date ("due fri", "by Nov 3", "next mon"); removed
/// together with it.
final _connectorBefore = RegExp(
  r'(?:\b(?:on|by|due|before|for|until|till|next|this)\s+)+$',
  caseSensitive: false,
);

/// Parse a pasted list. [today] decides the year of "30/10" and the day
/// "fri" means. Done items (`[x] …`, `✓ …`) and blank lines are skipped.
List<ParsedListItem> parseTextList(
  String text, {
  required DateTime today,
  int maxItems = 500,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final out = <ParsedListItem>[];
  for (final raw in text.split(RegExp(r'\r\n|\n|\r'))) {
    if (out.length >= maxItems) break;
    final item = _parseLine(raw, day);
    if (item != null) out.add(item);
  }
  return out;
}

ParsedListItem? _parseLine(String raw, DateTime today) {
  if (raw.trim().isEmpty || _doneMark.hasMatch(raw)) return null;
  final stripped = raw.replaceFirst(_bullet, '').trim();
  if (stripped.isEmpty) return null;

  var line = stripped;

  // Time first, so "5.30pm" is never mistaken for a date.
  int? hour;
  var minute = 0;
  final t12 = _time12.firstMatch(line);
  final t24 = t12 == null ? _time24.firstMatch(line) : null;
  if (t12 != null) {
    final h = int.parse(t12.group(1)!);
    final pm = t12.group(3)!.toLowerCase() == 'p';
    hour = h % 12 + (pm ? 12 : 0);
    minute = int.tryParse(t12.group(2) ?? '') ?? 0;
    line = _cut(line, t12.start, t12.end);
  } else if (t24 != null) {
    final hourText = t24.group(1)!;
    var h = int.parse(hourText);
    // "Lab 2:30" is the afternoon. Someone writing a 24-hour clock writes
    // "14:30", or "02:30" if they really mean the night.
    if (h >= 1 && h <= 6 && !hourText.startsWith('0')) h += 12;
    hour = h;
    minute = int.parse(t24.group(2)!);
    line = _cut(line, t24.start, t24.end);
  }

  final found = _findDate(line, today);
  DateTime? date;
  if (found != null) {
    date = found.date;
    line = _cut(line, found.start, found.end);
  }

  final title = _cleanTitle(line);
  return ParsedListItem(
    title: title.isEmpty ? _cleanTitle(stripped) : title,
    date: date,
    hour: hour,
    minute: minute,
  );
}

class _DateMatch {
  const _DateMatch(this.date, this.start, this.end);

  final DateTime date;
  final int start;
  final int end;
}

_DateMatch? _findDate(String line, DateTime today) {
  _DateMatch? at(Match m, DateTime? date) {
    if (date == null) return null;
    return _DateMatch(date, _startWithConnector(line, m.start), m.end);
  }

  final iso = _isoDate.firstMatch(line);
  if (iso != null) {
    final d = at(iso, _valid(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!)));
    if (d != null) return d;
  }

  final slash = _slashDate.firstMatch(line);
  if (slash != null) {
    final a = int.parse(slash.group(1)!);
    final b = int.parse(slash.group(2)!);
    // "Read 1/2 of book" is a fraction. Small numbers count as a date only
    // with a year, after "on"/"by"/"due"…, or closing the line.
    final datelike = slash.group(3) != null ||
        a > 12 ||
        b > 12 ||
        _connectorBefore.hasMatch(line.substring(0, slash.start)) ||
        _closesLine(line, slash.end);
    if (datelike) {
      // Day first, unless the numbers can only be month/day.
      final usOrder = b > 12 && a <= 12;
      final d = at(slash, _resolve(usOrder ? b : a, usOrder ? a : b, _year(slash.group(3)), today));
      if (d != null) return d;
    }
  }

  final dot = _dotDate.firstMatch(line);
  if (dot != null) {
    final d = at(dot, _resolve(int.parse(dot.group(1)!), int.parse(dot.group(2)!), _year(dot.group(3)), today));
    if (d != null) return d;
  }

  final dayMonth = _dayMonth.firstMatch(line);
  if (dayMonth != null) {
    final month = _monthNames[dayMonth.group(2)!.toLowerCase()];
    if (month != null) {
      final d = at(dayMonth, _resolve(int.parse(dayMonth.group(1)!), month, _year(dayMonth.group(3)), today));
      if (d != null) return d;
    }
  }

  final monthDay = _monthDay.firstMatch(line);
  if (monthDay != null) {
    final month = _monthNames[monthDay.group(1)!.toLowerCase()];
    if (month != null) {
      final d = at(monthDay, _resolve(int.parse(monthDay.group(2)!), month, _year(monthDay.group(3)), today));
      if (d != null) return d;
    }
  }

  final relative = _relative.firstMatch(line);
  if (relative != null) {
    final word = relative.group(1)!.toLowerCase();
    final offset = word == 'today' || word == 'tonight' ? 0 : 1;
    return at(relative, DateTime(today.year, today.month, today.day + offset));
  }

  final full = _weekdayFull.firstMatch(line);
  if (full != null) {
    return at(full, _weekdayFrom(line, full, _weekdayNames[full.group(1)!.toLowerCase()]!, today));
  }

  for (final short in _weekdayShort.allMatches(line)) {
    // "SAT prep", "Sun cream": a bare three-letter word is only a weekday when
    // something introduces it, or when it closes the line ("Essay draft fri").
    final introduced = _connectorBefore.hasMatch(line.substring(0, short.start));
    if (!introduced && !_closesLine(line, short.end)) continue;
    return at(short, _weekdayFrom(line, short, _weekdayNames[short.group(1)!.toLowerCase()]!, today));
  }
  return null;
}

/// Nothing but spaces and punctuation after [end].
bool _closesLine(String line, int end) => line.substring(end).replaceAll(RegExp(r'[\s.,;:!-]'), '').isEmpty;

/// The next [weekday] from [today] — today itself counts, unless the line says
/// "next", which means the coming one and never today.
DateTime _weekdayFrom(String line, Match m, int weekday, DateTime today) {
  final before = _connectorBefore.firstMatch(line.substring(0, m.start))?.group(0) ?? '';
  final next = RegExp(r'\bnext\b', caseSensitive: false).hasMatch(before);
  var diff = (weekday - today.weekday + 7) % 7;
  if (diff == 0 && next) diff = 7;
  return DateTime(today.year, today.month, today.day + diff);
}

int _startWithConnector(String line, int start) =>
    _connectorBefore.firstMatch(line.substring(0, start))?.start ?? start;

int? _year(String? raw) {
  if (raw == null) return null;
  final y = int.parse(raw);
  return y < 100 ? 2000 + y : y;
}

DateTime? _valid(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  return d.month == month && d.day == day ? d : null;
}

/// A day and month, with the year written or inferred. Without one, a date
/// more than two months back means next year ("5 Jan" written in October); a
/// recent one is simply overdue.
DateTime? _resolve(int day, int month, int? year, DateTime today) {
  if (year != null) return _valid(year, month, day);
  final thisYear = _valid(today.year, month, day);
  if (thisYear == null) return null;
  final cutoff = DateTime(today.year, today.month, today.day - 60);
  return thisYear.isBefore(cutoff) ? _valid(today.year + 1, month, day) : thisYear;
}

String _cut(String s, int start, int end) => '${s.substring(0, start)} ${s.substring(end)}';

final _edgeSeparators = RegExp(r'^[\s\-–—,:;|@]+|[\s\-–—,:;|@]+$');
final _danglingConnector = RegExp(r'\s+(?:at|on|by|due|before|for|until|till)$', caseSensitive: false);

String _cleanTitle(String s) {
  var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'\(\s*\)'), ' ');
  t = t.replaceAll(_edgeSeparators, '');
  t = t.replaceAll(_danglingConnector, '');
  t = t.replaceAll(_edgeSeparators, '');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}
