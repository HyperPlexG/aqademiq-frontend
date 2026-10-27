import 'package:meta/meta.dart';

import 'enums.dart';

// Calendar import / Reminder import (v2). Plain immutable classes rather than
// freezed: nothing here is serialised, and the wire mapping lives in
// `ApiImportSource` the same way `ApiTasksSource` owns the tasks wire shape.

/// Where an import's items were read. [wire] is the `source` the backend keys
/// its dedupe on, so the same calendar imported twice is recognised.
enum ImportSourceKind {
  /// The phone's own calendars — EventKit on iOS, CalendarContract on Android.
  /// Google, iCloud, Outlook and Samsung calendars all arrive through here.
  deviceCalendar('device_calendar'),

  /// Apple Reminders (iOS only — Android has no shared reminders store).
  deviceReminders('device_reminders'),

  /// An `.ics` file or calendar link, parsed on the device.
  ics('ics'),

  /// A pasted list, one reminder per line.
  text('text');

  const ImportSourceKind(this.wire);
  final String wire;
}

/// Why an item sits on the day it does.
enum ImportPlacement {
  /// On the day (and at the time) the source gave it.
  asScheduled,

  /// Due before today; placed on today rather than on a day already gone.
  overdue,

  /// No date in the source; placed on today.
  undated,
}

/// One calendar or reminders list on the device — a filter on the review screen.
@immutable
class ImportGroup {
  const ImportGroup({
    required this.id,
    required this.title,
    this.account,
    this.colorHex,
  });

  final String id;
  final String title;

  /// The account it syncs from ("iCloud", "you@gmail.com"), when known.
  final String? account;

  /// `#RRGGBB`, the colour the calendar has in the phone's own calendar app.
  final String? colorHex;
}

/// One event or reminder, already shaped as the task it will become.
@immutable
class ImportItem {
  const ImportItem({
    required this.externalId,
    required this.title,
    required this.date,
    this.startTime,
    this.durationMin,
    this.note,
    this.groupId,
    this.groupTitle,
    this.allDay = false,
    this.placement = ImportPlacement.asScheduled,
  });

  /// Stable per source, so a second import recognises what the first one added.
  /// For a calendar event occurrence it is `<event id>@<occurrence start>`.
  final String externalId;
  final String title;

  /// The local day the task lands on (date only).
  final DateTime date;

  /// Local wall-clock start, or null for an all-day event / undated reminder.
  final DateTime? startTime;
  final int? durationMin;
  final String? note;

  /// The calendar or list it came from.
  final String? groupId;
  final String? groupTitle;
  final bool allDay;
  final ImportPlacement placement;

  /// The Plan's bucket for this item — the same rule as `taskBucket()`, so an
  /// imported 15:00 lecture groups under Afternoon like one added by hand.
  DayPart get dayPart {
    final start = startTime;
    if (start == null) return DayPart.anytime;
    if (start.hour < 12) return DayPart.morning;
    if (start.hour < 17) return DayPart.afternoon;
    return DayPart.evening;
  }
}

/// What the server already holds for a set of items
/// (`POST /integrations/import/check`).
@immutable
class ImportCheck {
  const ImportCheck({
    this.existing = const <String>{},
    this.removed = const <String>{},
  });

  /// Imported before and still in the plan — shown locked, never re-sent.
  final Set<String> existing;

  /// Imported before and since deleted — shown unticked, but can be re-added.
  final Set<String> removed;
}

/// The outcome of an import.
@immutable
class ImportResult {
  const ImportResult({required this.imported, required this.skipped});

  /// New tasks created.
  final int imported;

  /// Items that were already in the plan.
  final int skipped;
}

/// A multi-request import that stopped part-way (usually the connection).
///
/// Everything before the failure is already in the plan, and trying again is
/// safe: the server skips what it has.
class ImportInterrupted implements Exception {
  const ImportInterrupted({required this.imported, required this.cause});

  final int imported;
  final Object cause;

  @override
  String toString() => 'ImportInterrupted(imported: $imported, cause: $cause)';
}
