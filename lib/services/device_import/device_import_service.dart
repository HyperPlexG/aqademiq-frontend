import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/import_item.dart';
import 'import_mapping.dart';

/// What the native side is asked to read.
enum DeviceImportKind {
  /// Calendar events (EventKit `.event` / Android CalendarContract).
  events,

  /// Apple Reminders (EventKit `.reminder`). iOS only.
  reminders,
}

/// The outcome of asking for access.
enum DeviceAccess {
  granted,

  /// Refused, now or earlier. Neither OS asks twice, so the way back is the
  /// app's page in Settings (`openAppSettings`).
  denied,

  /// Not something this platform has (reminders on Android, anything on web).
  unsupported,
}

/// Reads the phone's calendars and reminders over the `aqademiq/device_import`
/// channel — `ios/Runner/DeviceImportPlugin.swift` (EventKit) and
/// `android/…/DeviceImportPlugin.kt` (CalendarContract).
///
/// Read-only by construction: the channel has no method that writes, so an
/// import can never change the student's own calendar.
class DeviceImportService {
  const DeviceImportService();

  static const _channel = MethodChannel('aqademiq/device_import');

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Whether this phone has calendars the app can read.
  bool get supportsCalendars => _isMobile;

  /// Whether this phone has a reminders store the app can read — Apple
  /// Reminders. Android has no shared one; each reminders app keeps its own.
  bool get supportsReminders => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool _supports(DeviceImportKind kind) =>
      kind == DeviceImportKind.events ? supportsCalendars : supportsReminders;

  /// Ask for read access, showing the system prompt the first time.
  Future<DeviceAccess> requestAccess(DeviceImportKind kind) async {
    if (!_supports(kind)) return DeviceAccess.unsupported;
    try {
      final granted = await _channel.invokeMethod<bool>('requestAccess', {'kind': kind.name});
      return granted == true ? DeviceAccess.granted : DeviceAccess.denied;
    } on MissingPluginException {
      return DeviceAccess.unsupported;
    } on PlatformException catch (e) {
      debugPrint('[device-import] requestAccess(${kind.name}) failed: ${e.code} ${e.message}');
      return DeviceAccess.denied;
    }
  }

  /// The calendars (or reminder lists) on the phone.
  Future<List<ImportGroup>> groups(DeviceImportKind kind) async {
    final raw = await _channel.invokeListMethod<Object?>('calendars', {'kind': kind.name});
    return [
      for (final m in raw ?? const <Object?>[])
        if (m is Map<Object?, Object?>) ?groupFromMap(m),
    ];
  }

  /// Event occurrences starting in [from, to) in the given calendars, with
  /// repeating events already expanded by the platform.
  Future<List<ImportItem>> events({
    required Set<String> calendarIds,
    required DateTime from,
    required DateTime to,
  }) async {
    if (calendarIds.isEmpty) return const <ImportItem>[];
    final raw = await _channel.invokeListMethod<Object?>('events', {
      'calendarIds': calendarIds.toList(),
      'from': from.millisecondsSinceEpoch,
      'to': to.millisecondsSinceEpoch,
    });
    final fromMs = from.millisecondsSinceEpoch;
    final toMs = to.millisecondsSinceEpoch;
    return [
      for (final m in raw ?? const <Object?>[])
        if (m is Map<Object?, Object?>)
          // The platforms return events that merely overlap the window (and
          // Android's end is inclusive), so a trip that began last week or
          // tomorrow's all-day event shows up too. Only what starts in it.
          if (_startsWithin(m, fromMs, toMs)) ?itemFromDeviceEvent(m),
    ];
  }

  /// The incomplete reminders in the given lists.
  Future<List<ImportItem>> reminders({
    required Set<String> listIds,
    required DateTime today,
  }) async {
    if (listIds.isEmpty) return const <ImportItem>[];
    final raw = await _channel.invokeListMethod<Object?>('reminders', {
      'calendarIds': listIds.toList(),
    });
    return [
      for (final m in raw ?? const <Object?>[])
        if (m is Map<Object?, Object?>) ?itemFromDeviceReminder(m, today: today),
    ];
  }

  /// Starts in [fromMs, toMs).
  static bool _startsWithin(Map<Object?, Object?> m, int fromMs, int toMs) {
    final start = m['start'];
    if (start is! num) return false;
    if (m['allDay'] == true) {
      // Compare whole days for all-day events (see itemFromDeviceEvent).
      final day = m['startDay'];
      if (day is String) {
        return day.compareTo(_dayKey(fromMs)) >= 0 && day.compareTo(_dayKey(toMs)) < 0;
      }
    }
    final ms = start.toInt();
    return ms >= fromMs && ms < toMs;
  }

  /// The local day of [ms] as `yyyy-MM-dd`, the shape `startDay` arrives in.
  static String _dayKey(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

final deviceImportServiceProvider = Provider<DeviceImportService>((ref) => const DeviceImportService());
