import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../core/error/failure.dart';
import '../../../data/models/import_item.dart';
import '../../../data/repositories/import_repository.dart';
import '../../../services/device_import/device_import_service.dart';
import '../../../services/device_import/ics_fetcher.dart';
import '../../../services/device_import/ics_parser.dart';
import '../../../services/device_import/import_mapping.dart';
import '../../../services/device_import/text_list_parser.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../services/reminder_scheduler.dart';
import '../../plan/providers/plan_providers.dart';

/// "How far ahead" on the review screen, in days.
const importRangeOptions = <int>[7, 14, 30, 90];
const defaultImportRangeDays = 14;

/// The most items the review screen lists. A semester of a busy timetable at
/// three months is a few hundred; past this the list stops being reviewable.
const maxReviewItems = 500;

/// The most items read from a source in one go (before what is already in
/// the plan is set aside).
const maxReadItems = 2000;

/// Calendars every phone carries that are not the student's own schedule.
final _noisyCalendar = RegExp('birthday|holiday|siri suggestions|found in apps', caseSensitive: false);

/// "Today" for an import: the real date, always.
///
/// Not `AppDate.today()`, which is a fixture date in mock mode. The phone's
/// calendars and reminders are real whichever backend is in use, so reading
/// a June window from them in October would find nothing; one real "today"
/// keeps the window, the overdue rule and the day labels in agreement. Live,
/// the two are the same day.
DateTime importToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

enum ImportPhase {
  /// Reading the source (and asking the server what is already imported).
  loading,

  /// Items listed, waiting for the student.
  ready,

  /// The source could not be read; [ImportSessionState.message] says why.
  failed,

  /// Sending the picked items.
  importing,

  /// Finished; [ImportSessionState.result] holds the counts.
  done,
}

/// Everything the review screen shows. One import at a time — starting a new
/// one replaces this.
@immutable
class ImportSessionState {
  const ImportSessionState({
    required this.source,
    required this.title,
    this.phase = ImportPhase.loading,
    this.message,
    this.groups = const <ImportGroup>[],
    this.selectedGroups = const <String>{},
    this.rangeDays,
    this.items = const <ImportItem>[],
    this.truncated = false,
    this.check = const ImportCheck(),
    this.selected = const <String>{},
    this.tagId,
    this.done = 0,
    this.total = 0,
    this.result,
    this.hiddenInPlan = 0,
    this.firstAdded,
  });

  final ImportSourceKind source;
  final String title;
  final ImportPhase phase;

  /// An error to show — the read failing, or the import stopping part-way.
  final String? message;

  /// The phone's calendars / reminder lists (device sources only).
  final List<ImportGroup> groups;
  final Set<String> selectedGroups;

  /// Days ahead to read, for calendar sources. Null for reminders and lists,
  /// which have no window.
  final int? rangeDays;
  final List<ImportItem> items;

  /// More than [maxReviewItems] were found and the rest are not listed.
  final bool truncated;
  final ImportCheck check;

  /// External ids that will be imported.
  final Set<String> selected;

  /// Study tag for every imported task; null = untagged.
  final String? tagId;
  final int done;
  final int total;
  final ImportResult? result;

  /// Items already in the plan that were left out of [items] to keep the
  /// list under [maxReviewItems]. Counted so the screen can still say so.
  final int hiddenInPlan;

  /// The earliest day (today or later) this import added something to.
  final DateTime? firstAdded;

  bool isInPlan(ImportItem item) => check.existing.contains(item.externalId);

  bool wasRemoved(ImportItem item) => check.removed.contains(item.externalId);

  /// Items the student can still tick (everything not already in the plan).
  Iterable<ImportItem> get pickable => items.where((i) => !isInPlan(i));

  int get selectedCount => items.where((i) => selected.contains(i.externalId)).length;

  bool get busy => phase == ImportPhase.loading || phase == ImportPhase.importing;

  static const Object _keep = Object();

  ImportSessionState copyWith({
    ImportPhase? phase,
    Object? message = _keep,
    List<ImportGroup>? groups,
    Set<String>? selectedGroups,
    Object? rangeDays = _keep,
    List<ImportItem>? items,
    bool? truncated,
    ImportCheck? check,
    Set<String>? selected,
    Object? tagId = _keep,
    int? done,
    int? total,
    Object? result = _keep,
    int? hiddenInPlan,
    Object? firstAdded = _keep,
  }) {
    return ImportSessionState(
      source: source,
      title: title,
      phase: phase ?? this.phase,
      message: identical(message, _keep) ? this.message : message as String?,
      groups: groups ?? this.groups,
      selectedGroups: selectedGroups ?? this.selectedGroups,
      rangeDays: identical(rangeDays, _keep) ? this.rangeDays : rangeDays as int?,
      items: items ?? this.items,
      truncated: truncated ?? this.truncated,
      check: check ?? this.check,
      selected: selected ?? this.selected,
      tagId: identical(tagId, _keep) ? this.tagId : tagId as String?,
      done: done ?? this.done,
      total: total ?? this.total,
      result: identical(result, _keep) ? this.result : result as ImportResult?,
      hiddenInPlan: hiddenInPlan ?? this.hiddenInPlan,
      firstAdded: identical(firstAdded, _keep) ? this.firstAdded : firstAdded as DateTime?,
    );
  }
}

/// Drives Settings → Calendar import / Reminder import from "pick a source"
/// to "added to your plan".
///
/// Flow: a `start…` method resets the session and begins reading, the review
/// screen is pushed straight away and shows it loading, filters re-read, and
/// [runImport] sends what is ticked. Each read carries a generation number so
/// a slow read finishing after the student changed a filter is dropped
/// instead of overwriting the newer list.
class ImportSession extends Notifier<ImportSessionState> {
  IcsCalendar? _ics;
  Uri? _link;
  String _pasted = '';
  int _generation = 0;

  @override
  ImportSessionState build() =>
      const ImportSessionState(source: ImportSourceKind.deviceCalendar, title: '');

  // ---- starting --------------------------------------------------------------

  /// The phone's calendars. Access must already be granted.
  Future<void> startDeviceCalendars() => _startDevice(
        ImportSourceKind.deviceCalendar,
        DeviceImportKind.events,
        title: 'Phone calendars',
      );

  /// Apple Reminders. Access must already be granted.
  Future<void> startDeviceReminders() => _startDevice(
        ImportSourceKind.deviceReminders,
        DeviceImportKind.reminders,
        title: 'Apple Reminders',
      );

  Future<void> _startDevice(
    ImportSourceKind source,
    DeviceImportKind kind, {
    required String title,
  }) async {
    _reset(
      ImportSessionState(
        source: source,
        title: title,
        rangeDays: kind == DeviceImportKind.events ? defaultImportRangeDays : null,
      ),
    );
    final generation = _generation;
    try {
      final groups = await ref.read(deviceImportServiceProvider).groups(kind);
      if (generation != _generation) return;
      if (groups.isEmpty) {
        state = state.copyWith(
          phase: ImportPhase.failed,
          message: kind == DeviceImportKind.events
              ? 'There are no calendars on this phone yet.'
              : 'There are no reminder lists on this phone yet.',
        );
        return;
      }
      // Birthdays, public holidays and Siri's suggestions start unticked: as
      // tasks they would bury the classes the student came here for.
      final preferred = {
        for (final g in groups)
          if (kind == DeviceImportKind.reminders || !_noisyCalendar.hasMatch(g.title)) g.id,
      };
      state = state.copyWith(
        groups: groups,
        selectedGroups: preferred.isEmpty ? {for (final g in groups) g.id} : preferred,
      );
    } on Object catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(phase: ImportPhase.failed, message: _messageFor(e));
      return;
    }
    await _load();
  }

  /// A calendar file the student picked. [text] is its contents.
  Future<void> startIcsText(String text, {required String fileName}) async {
    _reset(
      ImportSessionState(
        source: ImportSourceKind.ics,
        title: fileName,
        rangeDays: defaultImportRangeDays,
      ),
    );
    if (_useIcs(text, fallbackTitle: fileName)) await _load();
  }

  /// A calendar link (webcal / iCal / .ics URL).
  Future<void> startIcsLink(Uri link) async {
    _reset(
      ImportSessionState(
        source: ImportSourceKind.ics,
        title: link.host,
        rangeDays: defaultImportRangeDays,
      ),
    );
    _link = link;
    final generation = _generation;
    final String text;
    try {
      text = await ref.read(icsFetcherProvider).fetch(link);
    } on Object catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(phase: ImportPhase.failed, message: _messageFor(e));
      return;
    }
    if (generation != _generation) return;
    if (_useIcs(text, fallbackTitle: link.host)) await _load();
  }

  /// A pasted list, one reminder per line.
  Future<void> startPastedList(String text) async {
    _reset(const ImportSessionState(source: ImportSourceKind.text, title: 'Pasted list'));
    _pasted = text;
    await _load();
  }

  void _reset(ImportSessionState fresh) {
    _generation++;
    _ics = null;
    _link = null;
    _pasted = '';
    state = fresh;
  }

  bool _useIcs(String text, {required String fallbackTitle}) {
    try {
      final calendar = parseIcs(text);
      _ics = calendar;
      final name = calendar.name;
      if (name != null && name != fallbackTitle) {
        // The calendar's own name ("CS Timetable") reads better than a file
        // or host name. `title` is fixed per session, so rebuild with it.
        state = ImportSessionState(source: state.source, title: name, rangeDays: state.rangeDays);
      }
      return true;
    } on Object catch (e) {
      state = state.copyWith(phase: ImportPhase.failed, message: _messageFor(e));
      return false;
    }
  }

  // ---- filters -----------------------------------------------------------------

  /// Whether the source itself was read (the calendar list, the file). Until
  /// it is, a filter has nothing to re-read, and re-reading would replace the
  /// real error with "nothing in this range".
  bool get _sourceReady => switch (state.source) {
        ImportSourceKind.ics => _ics != null,
        ImportSourceKind.deviceCalendar || ImportSourceKind.deviceReminders => state.groups.isNotEmpty,
        ImportSourceKind.text => true,
      };

  void toggleGroup(String id) {
    if (state.phase == ImportPhase.importing || !_sourceReady) return;
    final next = {...state.selectedGroups};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedGroups: next);
    unawaited(_load());
  }

  void setRange(int days) {
    if (state.rangeDays == null || state.rangeDays == days || state.phase == ImportPhase.importing) return;
    if (!_sourceReady) return;
    state = state.copyWith(rangeDays: days);
    unawaited(_load());
  }

  void setTag(String? tagId) => state = state.copyWith(tagId: tagId);

  void toggleItem(ImportItem item) {
    if (state.isInPlan(item) || state.phase == ImportPhase.importing) return;
    final next = {...state.selected};
    if (!next.remove(item.externalId)) next.add(item.externalId);
    state = state.copyWith(selected: next);
  }

  void selectAll() => state = state.copyWith(selected: {for (final i in state.pickable) i.externalId});

  void selectNone() => state = state.copyWith(selected: const <String>{});

  /// Whether [retry] can do anything. A file that is not a calendar will not
  /// become one by reading it again.
  bool get canRetry => switch (state.source) {
        ImportSourceKind.ics => _ics != null || _link != null,
        _ => true,
      };

  /// Read the source again after a failure — keeping the student's calendars,
  /// range and tag when only the items failed to load.
  Future<void> retry() async {
    switch (state.source) {
      case ImportSourceKind.deviceCalendar:
        if (state.groups.isNotEmpty) {
          await _load();
        } else {
          await startDeviceCalendars();
        }
      case ImportSourceKind.deviceReminders:
        if (state.groups.isNotEmpty) {
          await _load();
        } else {
          await startDeviceReminders();
        }
      case ImportSourceKind.ics:
        final link = _link;
        if (_ics != null) {
          await _load();
        } else if (link != null) {
          await startIcsLink(link);
        }
      case ImportSourceKind.text:
        await _load();
    }
  }

  // ---- reading -------------------------------------------------------------------

  Future<void> _load() async {
    final generation = ++_generation;
    state = state.copyWith(phase: ImportPhase.loading, message: null, result: null);
    try {
      // The same line pasted twice, or an event listed in two calendars,
      // is one item: the server would add it once, so the list shows it once.
      final seen = <String>{};
      final read = [
        for (final i in sortImportItems(await _read()))
          if (seen.add(i.externalId)) i,
      ];
      if (generation != _generation) return;
      final all = read.length > maxReadItems ? read.sublist(0, maxReadItems) : read;

      // Best-effort: offline, the list still shows and the server still
      // refuses duplicates at import time — only the badges are missing.
      var check = const ImportCheck();
      try {
        check = await ref.read(importRepositoryProvider).check(
              state.source,
              [for (final i in all) i.externalId],
            );
      } on Object {
        // Keep the empty check.
      }
      if (generation != _generation) return;

      // Over the review limit, what is already in the plan goes first: it
      // cannot be picked anyway, and keeping it would push the events still to
      // import off the end of the list for good.
      var items = all;
      if (items.length > maxReviewItems) {
        items = [for (final i in items) if (!check.existing.contains(i.externalId)) i];
      }
      final hiddenInPlan = all.length - items.length;
      final truncated = items.length > maxReviewItems || read.length > all.length;
      if (items.length > maxReviewItems) items = items.sublist(0, maxReviewItems);

      state = state.copyWith(
        phase: ImportPhase.ready,
        items: items,
        truncated: truncated,
        hiddenInPlan: hiddenInPlan,
        check: check,
        // Ticked by default: everything new. Something imported before and
        // deleted since stays unticked — the student already said no to it once.
        selected: {
          for (final i in items)
            if (!check.existing.contains(i.externalId) && !check.removed.contains(i.externalId)) i.externalId,
        },
      );
    } on Object catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(phase: ImportPhase.failed, message: _messageFor(e), items: const <ImportItem>[]);
    }
  }

  Future<List<ImportItem>> _read() async {
    final today = importToday();
    final to = DateTime(today.year, today.month, today.day + (state.rangeDays ?? defaultImportRangeDays));
    final device = ref.read(deviceImportServiceProvider);
    switch (state.source) {
      case ImportSourceKind.deviceCalendar:
        return device.events(calendarIds: state.selectedGroups, from: today, to: to);
      case ImportSourceKind.deviceReminders:
        return device.reminders(listIds: state.selectedGroups, today: today);
      case ImportSourceKind.ics:
        final calendar = _ics;
        if (calendar == null) return const <ImportItem>[];
        return [
          // One more than is kept, so _load can tell that something was cut.
          for (final o in calendar.occurrencesBetween(today, to, limit: maxReadItems + 1))
            itemFromIcs(o, groupTitle: state.title),
        ];
      case ImportSourceKind.text:
        return [
          // Read past the review limit, like every other source, so a very
          // long paste is trimmed (and says so) by _load rather than silently
          // losing its last lines here.
          for (final line in parseTextList(_pasted, today: today, maxItems: maxReadItems + 1))
            itemFromListLine(line, today: today),
        ];
    }
  }

  // ---- importing -------------------------------------------------------------------

  Future<void> runImport() async {
    final picked = [
      for (final i in state.items)
        if (state.selected.contains(i.externalId) && !state.isInPlan(i)) i,
    ];
    if (picked.isEmpty || state.busy) return;

    // The student can leave mid-import and start another one. The tasks this
    // one creates are real either way (so the plan is refreshed regardless),
    // but its progress and result must not be written over the newer session.
    final generation = _generation;
    final today = importToday();
    DateTime? firstAdded;
    for (final i in picked) {
      if (i.date.isBefore(today)) continue;
      if (firstAdded == null || i.date.isBefore(firstAdded)) firstAdded = i.date;
    }

    state = state.copyWith(phase: ImportPhase.importing, done: 0, total: picked.length, message: null);
    try {
      final result = await ref.read(importRepositoryProvider).importAll(
            state.source,
            picked,
            tagId: state.tagId,
            onProgress: (done, _) {
              if (generation == _generation) state = state.copyWith(done: done);
            },
          );
      _refreshPlan();
      if (generation != _generation) return;
      state = state.copyWith(
        phase: ImportPhase.done,
        result: result,
        check: _withExisting(picked),
        selected: const <String>{},
        firstAdded: firstAdded ?? today,
      );
      ref.read(hapticsProvider).taskCreated();
    } on ImportInterrupted catch (e) {
      _refreshPlan();
      if (generation != _generation) return;
      state = state.copyWith(
        phase: ImportPhase.ready,
        message: 'Added ${e.imported} before the connection dropped. '
            'Tap Add again for the rest — nothing will be added twice.',
      );
      ref.read(hapticsProvider).saveFailed();
    } on Object catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(phase: ImportPhase.ready, message: _messageFor(e));
      ref.read(hapticsProvider).saveFailed();
    }
  }

  ImportCheck _withExisting(List<ImportItem> imported) => ImportCheck(
        existing: {...state.check.existing, for (final i in imported) i.externalId},
        removed: {
          for (final id in state.check.removed)
            if (!imported.any((i) => i.externalId == id)) id,
        },
      );

  /// New tasks change both the Plan and what should be pending on the device
  /// — the same two refreshes Add task does after a save.
  void _refreshPlan() {
    ref.invalidate(dayTasksProvider);
    unawaited(ref.read(reminderSchedulerProvider).reconcile(force: true));
  }

  static String _messageFor(Object e) => switch (e) {
        Failure(:final message) => message,
        IcsParseException(:final message) => message,
        IcsFetchException(:final message) => message,
        PlatformException(code: 'denied') => 'Aqademiq needs access to read these. You can allow it in Settings.',
        PlatformException() => "Couldn't read them from this phone. Try again.",
        _ => 'Something went wrong. Please try again.',
      };
}

final importSessionProvider = NotifierProvider<ImportSession, ImportSessionState>(ImportSession.new);
