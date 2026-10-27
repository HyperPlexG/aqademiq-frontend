import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/device_import/device_import_service.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../settings/presentation/widgets/settings_scaffold.dart';
import 'import_actions.dart';
import 'widgets/import_widgets.dart';

/// Settings → Preferences → Calendar import (`settings-home`'s
/// `calendar_today` row). Pick where the events come from; the review screen
/// does the rest.
class CalendarImportScreen extends ConsumerWidget {
  const CalendarImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceImportServiceProvider);
    final iPhone = defaultTargetPlatform == TargetPlatform.iOS;
    return SettingsScaffold(
      title: 'Calendar import',
      children: [
        const ImportCaption(
          'Bring classes, exams and events into your plan. Each one you pick becomes a task on its day, at its time.',
        ),
        const GroupLabel('Import from'),
        SetGroup(
          children: [
            if (device.supportsCalendars)
              SettingsRow(
                label: "This phone's calendars",
                sub: iPhone
                    ? 'iCloud, Google, Outlook — every calendar on this iPhone'
                    : 'Google, Samsung, Outlook — every calendar on this phone',
                icon: Icons.smartphone,
                showChevron: true,
                onTap: () => unawaited(importFromPhoneCalendars(context, ref)),
              ),
            SettingsRow(
              label: 'Calendar link',
              sub: 'An iCal link from Moodle, Canvas, Google, Outlook or your university',
              icon: Icons.link,
              showChevron: true,
              onTap: () => unawaited(importFromCalendarLink(context, ref)),
            ),
            SettingsRow(
              label: 'Calendar file (.ics)',
              sub: 'A timetable or invite you saved or were sent',
              icon: Icons.upload_file_outlined,
              showChevron: true,
              last: true,
              onTap: () => unawaited(importFromCalendarFile(context, ref)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const ImportCaption(
          "Nothing changes in your calendar. Importing the same calendar again only adds what's new.",
        ),
      ],
    );
  }
}
