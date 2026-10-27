import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../services/device_import/device_import_service.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../settings/presentation/widgets/settings_scaffold.dart';
import 'import_actions.dart';
import 'widgets/import_widgets.dart';

/// Settings → Preferences → Reminder import (`settings-home`'s
/// `format_list_bulleted` row).
///
/// iPhone: Apple Reminders, read on the device, plus Paste a list. Android has
/// no reminders store other apps can read, so there it is Paste a list.
class ReminderImportScreen extends ConsumerWidget {
  const ReminderImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceImportServiceProvider);
    final apple = device.supportsReminders;
    return SettingsScaffold(
      title: 'Reminder import',
      children: [
        const ImportCaption(
          'Turn your reminders into tasks, so they sit in your plan with everything else.',
        ),
        const GroupLabel('Import from'),
        SetGroup(
          children: [
            if (apple)
              SettingsRow(
                label: 'Apple Reminders',
                sub: 'Your open reminders, including iCloud lists',
                icon: Icons.checklist,
                showChevron: true,
                onTap: () => unawaited(importFromAppleReminders(context, ref)),
              ),
            SettingsRow(
              label: 'Paste a list',
              sub: 'Copied from Samsung Reminder, Google Keep, Todoist, Notes or anywhere else',
              icon: Icons.content_paste,
              showChevron: true,
              last: true,
              onTap: () => unawaited(context.push(Routes.importPaste)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ImportCaption(
          apple
              ? 'Undated and overdue reminders go on today. Nothing changes in the Reminders app.'
              : 'Android keeps each reminders app to itself, so copy your list and paste it here. '
                  'Undated and overdue items go on today.',
        ),
      ],
    );
  }
}
