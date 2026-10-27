import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// An iCalendar (RFC 5545) reader for Calendar import — `.ics` files and
// calendar links (Google's "secret address in iCal format", Outlook's
// published calendars, Moodle / Canvas / Blackboard deadline feeds, university
// timetables).
//
// Parsed on the device rather than by the backend's older ICS endpoint for
// three reasons that all decide whether a timetable comes out right:
//  * TZID. `DTSTART;TZID=Asia/Dubai:20261028T090000` is 09:00 in Dubai. Read as
//    UTC it lands at 13:00, and every class in the file is four hours late.
//  * RRULE. A timetable is a handful of weekly events, not hundreds of single
//    ones. Without expansion only each class's first-ever meeting survives,
//    which is usually weeks in the past.
//  * VALARM. An alarm nested in an event carries its own DESCRIPTION, which
//    must not replace the event's.
//
// Pure apart from the timezone database, so it is unit tested directly
// (test/ics_parser_test.dart).

/// Thrown when text cannot be read as an iCalendar file.
class IcsParseException implements Exception {
  const IcsParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One occurrence of an event, placed in the device's local time.
@immutable
class IcsOccurrence {
  const IcsOccurrence({
    required this.uid,
    required this.key,
    required this.title,
    required this.start,
    required this.allDay,
    this.end,
    this.description,
    this.location,
  });

  final String uid;

  /// Identifies this occurrence within its event — the start instant in UTC
  /// milliseconds, or `yyyyMMdd` for an all-day event — so each meeting of a
  /// weekly class is its own item.
  final String key;
  final String title;

  /// Local start. Midnight of the day for an all-day event.
  final DateTime start;

  /// Local end (exclusive). Null when the event has no length.
  final DateTime? end;
  final bool allDay;
  final String? description;
  final String? location;
}

/// A parsed calendar file.
class IcsCalendar {
  IcsCalendar._(this.name, this._events);

  /// `X-WR-CALNAME` — the name Google, Apple and Outlook give the calendar.
  final String? name;
  final List<_Event> _events;

  /// Events in the file, before recurrence is expanded.
  int get eventCount => _events.length;

  /// Every occurrence starting in [from, to), sorted by start, with recurring
  /// events expanded and cancelled ones dropped. At most [limit] are returned
  /// — the earliest ones; ask for one more than you will show to learn
  /// whether anything was cut.
  List<IcsOccurrence> occurrencesBetween(
    DateTime from,
    DateTime to, {
    int limit = 2000,
  }) {
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;

    // An event carrying RECURRENCE-ID replaces one occurrence of the event
    // with the same UID (a lecture moved for one week only).
    final movedMs = <String, Set<int>>{};
    final movedDays = <String, Set<String>>{};
    for (final e in _events) {
      final rid = e.recurrenceId;
      if (rid == null) continue;
      if (rid.isDate) {
        (movedDays[e.uid] ??= <String>{}).add(_dayKey(rid.day));
      } else {
        (movedMs[e.uid] ??= <int>{}).add(_instantMs(rid.day, rid));
      }
    }

    // Everything in the window is collected before sorting, so the cut keeps
    // the earliest occurrences rather than whichever came first in the file.
    // The hard cap only guards against a pathological feed.
    final out = <IcsOccurrence>[];
    for (final e in _events) {
      if (out.length >= _maxCollected) break;
      if (e.cancelled) continue;
      final rule = e.rrule;
      if (rule == null || e.recurrenceId != null) {
        final occ = e.occurrenceOn(e.start.day);
        final ms = occ.start.millisecondsSinceEpoch;
        if (ms >= fromMs && ms < toMs) out.add(occ);
        continue;
      }
      _expand(
        e,
        rule,
        fromMs: fromMs,
        toMs: toMs,
        movedMs: movedMs[e.uid] ?? const <int>{},
        movedDays: movedDays[e.uid] ?? const <String>{},
        out: out,
        limit: _maxCollected,
      );
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out.length > limit ? out.sublist(0, limit) : out;
  }
}

/// Occurrences gathered before sorting, at most.
const int _maxCollected = 20000;

/// Parse iCalendar text. Throws [IcsParseException] when it is not a calendar.
IcsCalendar parseIcs(String raw) {
  var text = raw;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final upper = text.toUpperCase();
  if (!upper.contains('BEGIN:VCALENDAR') && !upper.contains('BEGIN:VEVENT')) {
    throw const IcsParseException("This doesn't look like a calendar file.");
  }

  // Unfold: a line break followed by one space or tab continues the line.
  final unfolded = text.replaceAll(RegExp(r'\r\n[ \t]|\n[ \t]|\r[ \t]'), '');
  final lines = unfolded.split(RegExp(r'\r\n|\n|\r'));

  String? calendarName;
  final events = <_Event>[];
  final stack = <String>[];
  Map<String, List<_Prop>>? current;

  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final prop = _Prop.parse(line);
    if (prop == null) continue;

    if (prop.name == 'BEGIN') {
      final component = prop.value.trim().toUpperCase();
      stack.add(component);
      if (component == 'VEVENT') current = <String, List<_Prop>>{};
      continue;
    }
    if (prop.name == 'END') {
      final component = prop.value.trim().toUpperCase();
      if (stack.isNotEmpty) stack.removeLast();
      if (component == 'VEVENT' && current != null) {
        final event = _Event.from(current);
        if (event != null) events.add(event);
        current = null;
      }
      continue;
    }

    final top = stack.isEmpty ? '' : stack.last;
    if (top == 'VEVENT' && current != null) {
      // Properties of a VALARM (or anything else nested) never reach here:
      // the top of the stack is then the nested component, not VEVENT.
      (current[prop.name] ??= <_Prop>[]).add(prop);
    } else if (top == 'VCALENDAR' && prop.name == 'X-WR-CALNAME') {
      final name = _unescape(prop.value).trim();
      if (name.isNotEmpty) calendarName = name;
    }
  }

  return IcsCalendar._(calendarName, events);
}

// ---- content lines ---------------------------------------------------------

class _Prop {
  _Prop(this.name, this.params, this.value);

  final String name;
  final Map<String, String> params;
  final String value;

  /// `NAME;PARAM=a;PARAM2="b:c":value`. A colon inside a quoted parameter
  /// value does not end the name part.
  static _Prop? parse(String line) {
    var inQuotes = false;
    var colon = -1;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ':' && !inQuotes) {
        colon = i;
        break;
      }
    }
    if (colon <= 0) return null;

    final head = _splitOutsideQuotes(line.substring(0, colon), ';');
    final params = <String, String>{};
    for (final p in head.skip(1)) {
      final eq = p.indexOf('=');
      if (eq <= 0) continue;
      var v = p.substring(eq + 1);
      if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
        v = v.substring(1, v.length - 1);
      }
      params[p.substring(0, eq).trim().toUpperCase()] = v;
    }
    return _Prop(head.first.trim().toUpperCase(), params, line.substring(colon + 1));
  }
}

List<String> _splitOutsideQuotes(String s, String separator) {
  final parts = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '"') inQuotes = !inQuotes;
    if (c == separator && !inQuotes) {
      parts.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  parts.add(buf.toString());
  return parts;
}

/// TEXT values escape `\n`, `\,`, `\;` and `\\` — decoded in one pass so `\\n`
/// stays a backslash followed by "n".
String _unescape(String s) => s.replaceAllMapped(
      RegExp(r'\\([nN,;\\])'),
      (m) {
        final c = m.group(1)!;
        return c == 'n' || c == 'N' ? '\n' : c;
      },
    );

String? _text(_Prop? p) {
  if (p == null) return null;
  final v = _unescape(p.value).trim();
  return v.isEmpty ? null : v;
}

// ---- dates and times -------------------------------------------------------

final _dateTimeRe = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
  caseSensitive: false,
);

/// A DATE or DATE-TIME value as written, before it is placed in time.
class _IcsTime {
  const _IcsTime({
    required this.year,
    required this.month,
    required this.dayOfMonth,
    this.hour = 0,
    this.minute = 0,
    this.second = 0,
    this.isDate = false,
    this.utc = false,
    this.tzid,
  });

  final int year;
  final int month;
  final int dayOfMonth;
  final int hour;
  final int minute;
  final int second;
  final bool isDate;
  final bool utc;
  final String? tzid;

  /// The calendar day as a UTC date carrier, so day arithmetic never meets DST.
  DateTime get day => DateTime.utc(year, month, dayOfMonth);

  static _IcsTime? parse(String value, Map<String, String> params) {
    final m = _dateTimeRe.firstMatch(value.trim());
    if (m == null) return null;
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (m.group(4) == null || params['VALUE']?.toUpperCase() == 'DATE') {
      return _IcsTime(year: year, month: month, dayOfMonth: day, isDate: true);
    }
    final hour = int.parse(m.group(4)!);
    final minute = int.parse(m.group(5)!);
    final second = m.group(6) == null ? 0 : int.parse(m.group(6)!);
    if (hour > 23 || minute > 59 || second > 60) return null;
    final tzid = params['TZID']?.trim();
    return _IcsTime(
      year: year,
      month: month,
      dayOfMonth: day,
      hour: hour,
      minute: minute,
      second: second,
      utc: m.group(7) != null,
      tzid: (tzid == null || tzid.isEmpty) ? null : tzid,
    );
  }
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}'
    '${day.month.toString().padLeft(2, '0')}'
    '${day.day.toString().padLeft(2, '0')}';

/// The instant (ms since epoch) of [t]'s clock time on calendar [day], in
/// [t]'s own zone: UTC, a TZID, or floating (the device's zone). A DATE value
/// is local midnight.
int _instantMs(DateTime day, _IcsTime t) {
  if (t.isDate) return DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
  if (t.utc) {
    return DateTime.utc(day.year, day.month, day.day, t.hour, t.minute, t.second)
        .millisecondsSinceEpoch;
  }
  final tzid = t.tzid;
  if (tzid != null) {
    final location = _location(tzid);
    if (location != null) {
      return tz.TZDateTime(location, day.year, day.month, day.day, t.hour, t.minute, t.second)
          .millisecondsSinceEpoch;
    }
  }
  // Floating, or a zone we cannot resolve: the device's own clock is the best
  // guess, and right for the common case of a file made in the same city.
  return DateTime(day.year, day.month, day.day, t.hour, t.minute, t.second)
      .millisecondsSinceEpoch;
}

final _durationRe = RegExp(
  r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
);

/// An RFC 5545 DURATION (`PT1H30M`, `P1D`, `P2W`) in milliseconds.
int? _durationMs(String value) {
  final m = _durationRe.firstMatch(value.trim().toUpperCase());
  if (m == null) return null;
  int part(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  final seconds = (part(2) * 7 + part(3)) * 86400 + part(4) * 3600 + part(5) * 60 + part(6);
  final ms = seconds * 1000;
  return m.group(1) == '-' ? -ms : ms;
}

// ---- time zones ------------------------------------------------------------

/// Outlook and Exchange write Windows zone names instead of IANA ones. The
/// common ones, so an Outlook timetable is not read as floating time.
const _windowsZones = <String, String>{
  'Arabian Standard Time': 'Asia/Dubai',
  'Arab Standard Time': 'Asia/Riyadh',
  'Arabic Standard Time': 'Asia/Baghdad',
  'India Standard Time': 'Asia/Kolkata',
  'Pakistan Standard Time': 'Asia/Karachi',
  'Bangladesh Standard Time': 'Asia/Dhaka',
  'Nepal Standard Time': 'Asia/Kathmandu',
  'Sri Lanka Standard Time': 'Asia/Colombo',
  'Myanmar Standard Time': 'Asia/Yangon',
  'SE Asia Standard Time': 'Asia/Bangkok',
  'Singapore Standard Time': 'Asia/Singapore',
  'China Standard Time': 'Asia/Shanghai',
  'Taipei Standard Time': 'Asia/Taipei',
  'Tokyo Standard Time': 'Asia/Tokyo',
  'Korea Standard Time': 'Asia/Seoul',
  'W. Australia Standard Time': 'Australia/Perth',
  'AUS Eastern Standard Time': 'Australia/Sydney',
  'New Zealand Standard Time': 'Pacific/Auckland',
  'Iran Standard Time': 'Asia/Tehran',
  'Afghanistan Standard Time': 'Asia/Kabul',
  'West Asia Standard Time': 'Asia/Tashkent',
  'Israel Standard Time': 'Asia/Jerusalem',
  'Turkey Standard Time': 'Europe/Istanbul',
  'Russian Standard Time': 'Europe/Moscow',
  'Egypt Standard Time': 'Africa/Cairo',
  'South Africa Standard Time': 'Africa/Johannesburg',
  'E. Africa Standard Time': 'Africa/Nairobi',
  'W. Central Africa Standard Time': 'Africa/Lagos',
  'Morocco Standard Time': 'Africa/Casablanca',
  'GMT Standard Time': 'Europe/London',
  'Greenwich Standard Time': 'Atlantic/Reykjavik',
  'W. Europe Standard Time': 'Europe/Berlin',
  'Central Europe Standard Time': 'Europe/Budapest',
  'Central European Standard Time': 'Europe/Warsaw',
  'Romance Standard Time': 'Europe/Paris',
  'GTB Standard Time': 'Europe/Bucharest',
  'FLE Standard Time': 'Europe/Helsinki',
  'E. Europe Standard Time': 'Europe/Chisinau',
  'Eastern Standard Time': 'America/New_York',
  'Central Standard Time': 'America/Chicago',
  'Mountain Standard Time': 'America/Denver',
  'US Mountain Standard Time': 'America/Phoenix',
  'Pacific Standard Time': 'America/Los_Angeles',
  'Alaskan Standard Time': 'America/Anchorage',
  'Hawaiian Standard Time': 'Pacific/Honolulu',
  'Atlantic Standard Time': 'America/Halifax',
  'Canada Central Standard Time': 'America/Regina',
  'SA Pacific Standard Time': 'America/Bogota',
  'E. South America Standard Time': 'America/Sao_Paulo',
  'Argentina Standard Time': 'America/Argentina/Buenos_Aires',
  'UTC': 'UTC',
  'Coordinated Universal Time': 'UTC',
};

final _zoneCache = <String, tz.Location?>{};

tz.Location? _location(String tzid) {
  if (_zoneCache.containsKey(tzid)) return _zoneCache[tzid];
  // The app initialises the database at launch (local_notifications.dart).
  // Only fill it here if that has not happened — re-initialising would reset
  // the scheduler's local zone.
  if (tz.timeZoneDatabase.locations.isEmpty) tz_data.initializeTimeZones();

  // Some generators prefix the IANA name with a path
  // ("/freeassociation.sourceforge.net/Tzfile/Europe/London").
  final segments = tzid.split('/').where((s) => s.isNotEmpty).toList();
  final candidates = <String>[
    tzid,
    ?_windowsZones[tzid],
    if (segments.length >= 3) segments.sublist(segments.length - 3).join('/'),
    if (segments.length >= 2) segments.sublist(segments.length - 2).join('/'),
  ];
  tz.Location? found;
  for (final name in candidates) {
    try {
      found = tz.getLocation(name);
      break;
    } on Object {
      // Not a zone name; try the next spelling.
    }
  }
  _zoneCache[tzid] = found;
  return found;
}

// ---- events ----------------------------------------------------------------

class _Event {
  _Event({
    required this.uid,
    required this.title,
    required this.start,
    required this.durationMs,
    required this.durationDays,
    required this.exInstants,
    required this.exDays,
    required this.cancelled,
    this.description,
    this.location,
    this.rrule,
    this.recurrenceId,
  });

  final String uid;
  final String title;
  final _IcsTime start;

  /// Timed events: length in milliseconds (0 when the event has no end).
  final int durationMs;

  /// All-day events: length in days (at least one).
  final int durationDays;
  final Set<int> exInstants;
  final Set<String> exDays;
  final bool cancelled;
  final String? description;
  final String? location;
  final _RRule? rrule;
  final _IcsTime? recurrenceId;

  static _Event? from(Map<String, List<_Prop>> fields) {
    _Prop? one(String name) {
      final list = fields[name];
      return list == null || list.isEmpty ? null : list.first;
    }

    final dtstart = one('DTSTART');
    if (dtstart == null) return null;
    final start = _IcsTime.parse(dtstart.value, dtstart.params);
    if (start == null) return null;

    final title = (_text(one('SUMMARY')) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final uidValue = one('UID')?.value.trim() ?? '';
    final uid = uidValue.isNotEmpty ? uidValue : 'nouid-${dtstart.value.trim()}-$title';

    final dtend = one('DTEND');
    final end = dtend == null ? null : _IcsTime.parse(dtend.value, dtend.params);
    final duration = one('DURATION');
    var durationMs = 0;
    var durationDays = 1;
    if (start.isDate) {
      int? days;
      if (end != null) {
        days = end.day.difference(start.day).inDays;
      } else if (duration != null) {
        final ms = _durationMs(duration.value);
        if (ms != null) days = (ms / Duration.millisecondsPerDay).round();
      }
      if (days != null && days > 1) durationDays = days;
    } else if (end != null) {
      durationMs = math.max(0, _instantMs(end.day, end) - _instantMs(start.day, start));
    } else if (duration != null) {
      durationMs = math.max(0, _durationMs(duration.value) ?? 0);
    }

    final exInstants = <int>{};
    final exDays = <String>{};
    for (final p in fields['EXDATE'] ?? const <_Prop>[]) {
      for (final v in p.value.split(',')) {
        final t = _IcsTime.parse(v, p.params);
        if (t == null) continue;
        if (t.isDate) {
          exDays.add(_dayKey(t.day));
        } else {
          exInstants.add(_instantMs(t.day, t));
        }
      }
    }

    final rruleProp = one('RRULE');
    final ridProp = one('RECURRENCE-ID');
    return _Event(
      uid: uid,
      title: title,
      start: start,
      durationMs: durationMs,
      durationDays: durationDays,
      exInstants: exInstants,
      exDays: exDays,
      cancelled: one('STATUS')?.value.trim().toUpperCase() == 'CANCELLED',
      description: _text(one('DESCRIPTION')),
      location: _text(one('LOCATION')),
      rrule: rruleProp == null ? null : _RRule.parse(rruleProp.value),
      recurrenceId: ridProp == null ? null : _IcsTime.parse(ridProp.value, ridProp.params),
    );
  }

  /// This event on calendar [day] (a UTC date carrier), at its own clock time.
  IcsOccurrence occurrenceOn(DateTime day) {
    final name = title.isEmpty ? 'Untitled event' : title;
    if (start.isDate) {
      return IcsOccurrence(
        uid: uid,
        key: _dayKey(day),
        title: name,
        start: DateTime(day.year, day.month, day.day),
        end: DateTime(day.year, day.month, day.day + durationDays),
        allDay: true,
        description: description,
        location: location,
      );
    }
    final ms = _instantMs(day, start);
    return IcsOccurrence(
      uid: uid,
      key: '$ms',
      title: name,
      start: DateTime.fromMillisecondsSinceEpoch(ms),
      end: durationMs > 0 ? DateTime.fromMillisecondsSinceEpoch(ms + durationMs) : null,
      allDay: false,
      description: description,
      location: location,
    );
  }
}

// ---- recurrence ------------------------------------------------------------

const _weekdayCodes = <String, int>{
  'MO': DateTime.monday,
  'TU': DateTime.tuesday,
  'WE': DateTime.wednesday,
  'TH': DateTime.thursday,
  'FR': DateTime.friday,
  'SA': DateTime.saturday,
  'SU': DateTime.sunday,
};

/// `MO`, `2TU` (second Tuesday), `-1FR` (last Friday).
class _ByDay {
  const _ByDay(this.weekday, this.ordinal);

  final int weekday;
  final int? ordinal;

  static _ByDay? parse(String token) {
    final m = RegExp(r'^([+-]?\d{1,2})?(MO|TU|WE|TH|FR|SA|SU)$').firstMatch(token.trim().toUpperCase());
    if (m == null) return null;
    final ordinal = m.group(1) == null ? null : int.parse(m.group(1)!);
    if (ordinal == 0) return null;
    return _ByDay(_weekdayCodes[m.group(2)]!, ordinal);
  }
}

class _RRule {
  _RRule({
    required this.freq,
    required this.interval,
    required this.byDay,
    required this.byMonthDay,
    required this.byMonth,
    required this.weekStart,
    this.count,
    this.until,
  });

  final String freq;
  final int interval;
  final List<_ByDay> byDay;
  final List<int> byMonthDay;
  final List<int> byMonth;
  final int weekStart;
  final int? count;
  final _IcsTime? until;

  /// Null for a rule this expander does not implement. Guessing would put
  /// classes on the wrong days, so such an event keeps only its first meeting.
  static _RRule? parse(String value) {
    final parts = <String, String>{};
    for (final kv in value.split(';')) {
      final eq = kv.indexOf('=');
      if (eq > 0) parts[kv.substring(0, eq).trim().toUpperCase()] = kv.substring(eq + 1).trim();
    }
    final freq = parts['FREQ']?.toUpperCase();
    if (freq == null || !const {'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'}.contains(freq)) return null;
    for (final unsupported in const ['BYSETPOS', 'BYHOUR', 'BYMINUTE', 'BYSECOND', 'BYWEEKNO', 'BYYEARDAY']) {
      if (parts.containsKey(unsupported)) return null;
    }

    final byDayRaw = parts['BYDAY'] ?? '';
    final byDay = <_ByDay>[];
    for (final token in byDayRaw.split(',')) {
      if (token.trim().isEmpty) continue;
      final b = _ByDay.parse(token);
      if (b == null) return null;
      byDay.add(b);
    }
    if (freq == 'YEARLY' && byDay.isNotEmpty) return null;
    if ((freq == 'DAILY' || freq == 'WEEKLY') && byDay.any((b) => b.ordinal != null)) return null;

    final interval = int.tryParse(parts['INTERVAL'] ?? '') ?? 1;
    final countRaw = parts['COUNT'];
    final untilRaw = parts['UNTIL'];
    return _RRule(
      freq: freq,
      interval: interval < 1 ? 1 : interval,
      byDay: byDay,
      byMonthDay: _ints(parts['BYMONTHDAY']).where((n) => n != 0 && n.abs() <= 31).toList(),
      byMonth: _ints(parts['BYMONTH']).where((n) => n >= 1 && n <= 12).toList(),
      weekStart: _weekdayCodes[parts['WKST']?.toUpperCase()] ?? DateTime.monday,
      count: countRaw == null ? null : int.tryParse(countRaw),
      until: untilRaw == null ? null : _IcsTime.parse(untilRaw, const <String, String>{}),
    );
  }

  static List<int> _ints(String? csv) {
    if (csv == null || csv.isEmpty) return const <int>[];
    return [
      for (final s in csv.split(','))
        if (int.tryParse(s.trim()) != null) int.parse(s.trim()),
    ];
  }

  bool matchesMonth(DateTime d) => byMonth.isEmpty || byMonth.contains(d.month);

  bool matchesWeekday(DateTime d) => byDay.isEmpty || byDay.any((b) => b.weekday == d.weekday);

  bool matchesMonthDay(DateTime d) {
    if (byMonthDay.isEmpty) return true;
    final daysInMonth = DateTime.utc(d.year, d.month + 1, 0).day;
    return byMonthDay.any((n) => n > 0 ? d.day == n : d.day == daysInMonth + n + 1);
  }

  /// The days of [month] this rule selects, ascending. [startDay] is
  /// DTSTART's day of month, used when no BYDAY / BYMONTHDAY is given (a month
  /// without that day is skipped, as RFC 5545 says).
  List<int> monthDays(int year, int month, int startDay) {
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    Set<int>? days;
    if (byDay.isNotEmpty) {
      days = <int>{};
      for (final b in byDay) {
        days.addAll(_weekdaysIn(year, month, daysInMonth, b));
      }
    }
    if (byMonthDay.isNotEmpty) {
      final fromMonthDay = {
        for (final n in byMonthDay) n > 0 ? n : daysInMonth + n + 1,
      }..removeWhere((n) => n < 1 || n > daysInMonth);
      days = days == null ? fromMonthDay : days.intersection(fromMonthDay);
    }
    days ??= startDay <= daysInMonth ? <int>{startDay} : <int>{};
    return days.toList()..sort();
  }

  static List<int> _weekdaysIn(int year, int month, int daysInMonth, _ByDay b) {
    final all = <int>[
      for (var d = 1; d <= daysInMonth; d++)
        if (DateTime.utc(year, month, d).weekday == b.weekday) d,
    ];
    final ordinal = b.ordinal;
    if (ordinal == null) return all;
    final i = ordinal > 0 ? ordinal - 1 : all.length + ordinal;
    return i >= 0 && i < all.length ? <int>[all[i]] : const <int>[];
  }
}

/// Candidate days (UTC date carriers) for [r], ascending, from DTSTART's day
/// [first]. When [skipTo] is given (no COUNT) the rule jumps to just before it
/// instead of walking every period since a timetable began.
Iterable<DateTime> _candidates(_RRule r, DateTime first, DateTime? skipTo) sync* {
  const maxPeriods = 1500;
  switch (r.freq) {
    case 'DAILY':
      {
        var k0 = 0;
        if (skipTo != null && skipTo.isAfter(first)) {
          k0 = math.max(0, skipTo.difference(first).inDays ~/ r.interval - 1);
        }
        for (var k = k0; k < k0 + maxPeriods; k++) {
          final d = DateTime.utc(first.year, first.month, first.day + k * r.interval);
          if (r.matchesMonth(d) && r.matchesWeekday(d) && r.matchesMonthDay(d)) yield d;
        }
      }
    case 'WEEKLY':
      {
        final offset = (first.weekday - r.weekStart + 7) % 7;
        final weekBegin = DateTime.utc(first.year, first.month, first.day - offset);
        // Days of the week in WKST order, so each week yields them ascending.
        final days = (r.byDay.isEmpty ? <int>[first.weekday] : r.byDay.map((b) => b.weekday).toSet().toList())
          ..sort((a, b) => ((a - r.weekStart + 7) % 7).compareTo((b - r.weekStart + 7) % 7));
        var k0 = 0;
        if (skipTo != null && skipTo.isAfter(weekBegin)) {
          k0 = math.max(0, skipTo.difference(weekBegin).inDays ~/ 7 ~/ r.interval - 1);
        }
        for (var k = k0; k < k0 + maxPeriods; k++) {
          for (final weekday in days) {
            final d = DateTime.utc(
              weekBegin.year,
              weekBegin.month,
              weekBegin.day + k * 7 * r.interval + (weekday - r.weekStart + 7) % 7,
            );
            if (!d.isBefore(first) && r.matchesMonth(d)) yield d;
          }
        }
      }
    case 'MONTHLY':
      {
        var k0 = 0;
        if (skipTo != null && skipTo.isAfter(first)) {
          final months = (skipTo.year - first.year) * 12 + (skipTo.month - first.month);
          k0 = math.max(0, months ~/ r.interval - 1);
        }
        for (var k = k0; k < k0 + maxPeriods; k++) {
          final monthBegin = DateTime.utc(first.year, first.month + k * r.interval);
          if (!r.matchesMonth(monthBegin)) continue;
          for (final day in r.monthDays(monthBegin.year, monthBegin.month, first.day)) {
            final d = DateTime.utc(monthBegin.year, monthBegin.month, day);
            if (!d.isBefore(first)) yield d;
          }
        }
      }
    case 'YEARLY':
      {
        var k0 = 0;
        if (skipTo != null && skipTo.year > first.year) {
          k0 = math.max(0, (skipTo.year - first.year) ~/ r.interval - 1);
        }
        final months = r.byMonth.isEmpty ? <int>[first.month] : (r.byMonth.toSet().toList()..sort());
        for (var k = k0; k < k0 + maxPeriods; k++) {
          final year = first.year + k * r.interval;
          for (final month in months) {
            for (final day in r.monthDays(year, month, first.day)) {
              final d = DateTime.utc(year, month, day);
              if (!d.isBefore(first)) yield d;
            }
          }
        }
      }
  }
}

void _expand(
  _Event e,
  _RRule rule, {
  required int fromMs,
  required int toMs,
  required Set<int> movedMs,
  required Set<String> movedDays,
  required List<IcsOccurrence> out,
  required int limit,
}) {
  final first = e.start.day;
  final until = rule.until;
  final untilDay = until != null && until.isDate ? until.day : null;
  final untilMs = until != null && !until.isDate ? _instantMs(until.day, until) : null;
  final count = rule.count;

  // COUNT has to be walked from DTSTART (every occurrence counts, even the
  // ones before the window). Without it, jump to a day before the window.
  DateTime? skipTo;
  if (count == null) {
    final fromLocal = DateTime.fromMillisecondsSinceEpoch(fromMs);
    skipTo = DateTime.utc(fromLocal.year, fromLocal.month, fromLocal.day - 1);
  }

  var n = 0;

  /// False once the rule is exhausted or past the window.
  bool consider(DateTime day) {
    n++;
    if (count != null && n > count) return false;
    if (untilDay != null && day.isAfter(untilDay)) return false;
    final occ = e.occurrenceOn(day);
    final ms = occ.start.millisecondsSinceEpoch;
    if (untilMs != null && ms > untilMs) return false;
    if (ms >= toMs) return false;
    final key = _dayKey(day);
    final excluded = e.exDays.contains(key) ||
        movedDays.contains(key) ||
        (!e.start.isDate && (e.exInstants.contains(ms) || movedMs.contains(ms)));
    if (!excluded && ms >= fromMs) {
      out.add(occ);
      if (out.length >= limit) return false;
    }
    return true;
  }

  // DTSTART is always the first occurrence, whether or not it fits the rule.
  if (!consider(first)) return;
  for (final day in _candidates(rule, first, skipTo)) {
    if (!day.isAfter(first)) continue;
    if (!consider(day)) return;
  }
}
