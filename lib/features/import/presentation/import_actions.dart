import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../services/app_settings.dart';
import '../../../services/device_import/calendar_link.dart';
import '../../../services/device_import/device_import_service.dart';
import '../providers/import_session.dart';
import 'sheets/ics_link_sheet.dart';

// What each "Import from" row does. Every path ends the same way: start the
// import session, then show the review screen, which reads it.

/// "This phone's calendars".
Future<void> importFromPhoneCalendars(BuildContext context, WidgetRef ref) async {
  final access = await ref.read(deviceImportServiceProvider).requestAccess(DeviceImportKind.events);
  if (!context.mounted) return;
  switch (access) {
    case DeviceAccess.granted:
      unawaited(ref.read(importSessionProvider.notifier).startDeviceCalendars());
      unawaited(context.push(Routes.importReview));
    case DeviceAccess.denied:
      _offerSettings(
        context,
        'Aqademiq needs access to your calendars to import from this phone. You can allow it in Settings.',
      );
    case DeviceAccess.unsupported:
      _say(context, "This phone's calendars can't be read here.");
  }
}

/// "Apple Reminders" (iOS).
Future<void> importFromAppleReminders(BuildContext context, WidgetRef ref) async {
  final access = await ref.read(deviceImportServiceProvider).requestAccess(DeviceImportKind.reminders);
  if (!context.mounted) return;
  switch (access) {
    case DeviceAccess.granted:
      unawaited(ref.read(importSessionProvider.notifier).startDeviceReminders());
      unawaited(context.push(Routes.importReview));
    case DeviceAccess.denied:
      _offerSettings(
        context,
        'Aqademiq needs access to your reminders to import them. You can allow it in Settings.',
      );
    case DeviceAccess.unsupported:
      _say(context, "Reminders can't be read on this phone — try Paste a list.");
  }
}

/// "Calendar link".
Future<void> importFromCalendarLink(BuildContext context, WidgetRef ref) async {
  final raw = await showIcsLinkSheet(context);
  if (raw == null || raw.trim().isEmpty || !context.mounted) return;
  final link = normalizeCalendarLink(raw);
  if (link == null) {
    _say(context, "That doesn't look like a calendar link. Copy the whole address and try again.");
    return;
  }
  unawaited(ref.read(importSessionProvider.notifier).startIcsLink(link));
  unawaited(context.push(Routes.importReview));
}

/// "Calendar file (.ics)".
Future<void> importFromCalendarFile(BuildContext context, WidgetRef ref) async {
  const typeGroup = XTypeGroup(
    label: 'Calendar',
    extensions: <String>['ics', 'ical', 'icalendar', 'ifb'],
    mimeTypes: <String>['text/calendar', 'application/ics', 'text/x-vcalendar', 'application/octet-stream'],
    // iOS filters by UTI only. Mail and WhatsApp often save an .ics without
    // its calendar type, so public.data keeps it pickable; a file that is not
    // a calendar is turned away by the parser with a readable message.
    uniformTypeIdentifiers: <String>['com.apple.ical.ics', 'public.calendar-event', 'public.data'],
  );
  final XFile? file;
  try {
    file = await openFile(acceptedTypeGroups: const [typeGroup]);
  } on Object catch (e) {
    debugPrint('[import] file picker failed: $e');
    if (context.mounted) _say(context, "Couldn't open your files. Try again.");
    return;
  }
  if (file == null || !context.mounted) return;

  final String text;
  try {
    text = await _readText(file);
  } on Object {
    if (context.mounted) _say(context, "Couldn't read that file.");
    return;
  }
  if (!context.mounted) return;
  final name = file.name.replaceAll(RegExp(r'\.(ics|ical|icalendar|ifb)$', caseSensitive: false), '');
  unawaited(
    ref.read(importSessionProvider.notifier).startIcsText(text, fileName: name.isEmpty ? 'Calendar file' : name),
  );
  unawaited(context.push(Routes.importReview));
}

/// UTF-8, as RFC 5545 requires — but older exporters write Latin-1, and a
/// calendar with "Café" in it should not fail outright.
Future<String> _readText(XFile file) async {
  final bytes = await file.readAsBytes();
  if (bytes.length > maxCalendarBytes) {
    throw const FormatException('Calendar file is too large');
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
}

/// Neither OS shows a refused permission prompt twice, so the only way back
/// is the app's page in Settings.
void _offerSettings(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text(message),
        action: SnackBarAction(label: 'Settings', onPressed: () => unawaited(openAppSettings())),
      ),
    );
}
