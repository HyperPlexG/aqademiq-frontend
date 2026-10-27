import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../data/models/import_item.dart';
import 'ics_parser.dart';
import 'text_list_parser.dart';

// Every source — the phone's calendars, Apple Reminders, an .ics file, a
// pasted list — is mapped onto one [ImportItem] shape here, so the review
// screen and the import itself never care where an item came from. Pure, so
// the rules are unit tested (test/import_mapping_test.dart).

/// The backend allows 400 characters; a little headroom for the source prefix.
const maxExternalIdLength = 380;

/// Calendar invites can carry pages of meeting boilerplate. A task note is for
/// the part a student will actually read.
const maxImportNoteLength = 1000;

/// An id the server accepts, still unique and still stable.
///
/// Cutting a long id would drop its `@start` / `@date` suffix, the very part
/// that tells one meeting of a class from the next, and they would all collapse
/// into one item. So the suffix is kept and the long part is replaced by its
/// hash.
String clipExternalId(String id) {
  if (id.length <= maxExternalIdLength) return id;
  final at = id.lastIndexOf('@');
  final suffix = at > 0 && id.length - at <= 64 ? id.substring(at) : '';
  final head = suffix.isEmpty ? id : id.substring(0, at);
  return '#${sha256.convert(utf8.encode(head))}$suffix';
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Minutes from [start] to [end], or null when there is no positive length.
///
/// Capped at midnight: the Plan draws a task inside its own day, and a
/// weekend-long event would otherwise spill a block off the bottom of it.
int? durationMinutes(DateTime start, DateTime? end) {
  if (end == null) return null;
  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) return null;
  final toMidnight = DateTime(start.year, start.month, start.day + 1).difference(start).inMinutes;
  return minutes > toMidnight ? toMidnight : minutes;
}

/// The task note: where it is, then what the source said about it.
String? buildImportNote({String? notes, String? location}) {
  final parts = <String>[
    if (location != null && location.trim().isNotEmpty) 'Location: ${location.trim()}',
    if (notes != null && notes.trim().isNotEmpty) notes.trim(),
  ];
  if (parts.isEmpty) return null;
  final note = parts.join('\n\n');
  return note.length > maxImportNoteLength ? '${note.substring(0, maxImportNoteLength - 1)}…' : note;
}

String _titleOr(String? raw, String fallback) {
  final t = raw?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return t.isEmpty ? fallback : t;
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

DateTime? _parseYmd(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A calendar or reminders list from the native channel.
ImportGroup? groupFromMap(Map<Object?, Object?> m) {
  final id = _str(m['id']);
  if (id == null) return null;
  return ImportGroup(
    id: id,
    title: _titleOr(_str(m['title']), 'Untitled'),
    account: _str(m['account']),
    colorHex: _str(m['color']),
  );
}

/// One event occurrence from the native channel (EventKit / CalendarContract).
///
/// `start` / `end` are epoch milliseconds; `startDay` is the occurrence's
/// calendar day as the platform sees it, which is what an all-day event uses
/// — Android stores all-day events at UTC midnight, so reading the day off the
/// instant would put them on the previous day anywhere west of Greenwich.
ImportItem? itemFromDeviceEvent(Map<Object?, Object?> m) {
  final id = _str(m['id']);
  final startMs = _int(m['start']);
  if (id == null || startMs == null) return null;
  final allDay = m['allDay'] == true;
  final start = DateTime.fromMillisecondsSinceEpoch(startMs);
  final endMs = _int(m['end']);
  final end = endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs);
  final startDay = _str(m['startDay']);
  return ImportItem(
    // One item per occurrence: every meeting of a weekly class is its own
    // task. An all-day occurrence is keyed by its day — on iOS its instant is
    // midnight in the phone's current zone, which moves when the student
    // travels, and the same holiday would come back as a new item.
    externalId: clipExternalId(allDay && startDay != null ? '$id@$startDay' : '$id@$startMs'),
    title: _titleOr(_str(m['title']), 'Untitled event'),
    date: allDay ? (_parseYmd(startDay) ?? dateOnly(start)) : dateOnly(start),
    startTime: allDay ? null : start,
    durationMin: allDay ? null : durationMinutes(start, end),
    note: buildImportNote(notes: _str(m['notes']), location: _str(m['location'])),
    groupId: _str(m['calendarId']),
    groupTitle: _str(m['calendarTitle']),
    allDay: allDay,
  );
}

/// One Apple reminder from the native channel.
///
/// An undated or overdue reminder goes on [today]: a task filed on a day that
/// has already gone is a task nobody sees.
ImportItem? itemFromDeviceReminder(Map<Object?, Object?> m, {required DateTime today}) {
  final id = _str(m['id']);
  if (id == null) return null;
  final day = dateOnly(today);
  final dueMs = _int(m['due']);

  final DateTime date;
  DateTime? start;
  final ImportPlacement placement;
  if (dueMs == null) {
    date = day;
    placement = ImportPlacement.undated;
  } else {
    final due = DateTime.fromMillisecondsSinceEpoch(dueMs);
    if (dateOnly(due).isBefore(day)) {
      date = day;
      placement = ImportPlacement.overdue;
    } else {
      date = dateOnly(due);
      if (m['dueHasTime'] == true) start = due;
      placement = ImportPlacement.asScheduled;
    }
  }
  return ImportItem(
    externalId: clipExternalId(id),
    title: _titleOr(_str(m['title']), 'Untitled reminder'),
    date: date,
    startTime: start,
    note: buildImportNote(notes: _str(m['notes'])),
    groupId: _str(m['listId']),
    groupTitle: _str(m['listTitle']),
    placement: placement,
  );
}

/// One occurrence from an .ics file or link.
ImportItem itemFromIcs(IcsOccurrence o, {String? groupTitle}) {
  return ImportItem(
    externalId: clipExternalId('${o.uid}@${o.key}'),
    title: o.title,
    date: dateOnly(o.start),
    startTime: o.allDay ? null : o.start,
    durationMin: o.allDay ? null : durationMinutes(o.start, o.end),
    note: buildImportNote(notes: o.description, location: o.location),
    groupTitle: groupTitle,
    allDay: o.allDay,
  );
}

/// One line of a pasted list.
///
/// The id is the title plus the date written on the line, so pasting the same
/// list again next week does not add everything twice — and an undated line is
/// keyed as undated, not by the day it happened to be pasted.
ImportItem itemFromListLine(ParsedListItem p, {required DateTime today}) {
  final day = dateOnly(today);
  final written = p.date;

  final DateTime date;
  final ImportPlacement placement;
  if (written == null) {
    date = day;
    placement = ImportPlacement.undated;
  } else if (written.isBefore(day)) {
    date = day;
    placement = ImportPlacement.overdue;
  } else {
    date = written;
    placement = ImportPlacement.asScheduled;
  }
  final hour = p.hour;
  final start = hour != null && placement != ImportPlacement.overdue
      ? DateTime(date.year, date.month, date.day, hour, p.minute)
      : null;

  final key = p.title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return ImportItem(
    externalId: clipExternalId('$key@${written == null ? 'undated' : _ymd(written)}'),
    title: p.title,
    date: date,
    startTime: start,
    placement: placement,
  );
}

/// Day, then time (all-day and untimed first), then title.
int compareImportItems(ImportItem a, ImportItem b) {
  final byDay = a.date.compareTo(b.date);
  if (byDay != 0) return byDay;
  final sa = a.startTime;
  final sb = b.startTime;
  if (sa == null && sb != null) return -1;
  if (sa != null && sb == null) return 1;
  if (sa != null && sb != null) {
    final byTime = sa.compareTo(sb);
    if (byTime != 0) return byTime;
  }
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

List<ImportItem> sortImportItems(Iterable<ImportItem> items) => items.toList()..sort(compareImportItems);
