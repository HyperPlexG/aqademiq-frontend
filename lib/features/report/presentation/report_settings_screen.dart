import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../settings/presentation/widgets/settings_scaffold.dart';
import '../report_copy.dart';
import '../report_optout.dart';

/// The report's off switch, and the promises that make it safe to leave on.
///
/// The toggle is the point of the screen: §6 of the design starts with a real
/// off switch, and everything else depends on it — a weekly report you cannot
/// decline is one that can reach you every seven days forever. One tap,
/// honoured immediately, no confirmation, no win-back, no re-prompt later.
///
/// The list below it is not marketing. Each row is a commitment enforced
/// somewhere in code, and stating them where the student can read them is the
/// only way the commitment is worth anything to them:
///
///  * **Notify you** — nothing schedules a notification for this feature.
///    Pushing on good weeks and staying quiet on bad ones turns the missing
///    notification into a lock-screen verdict.
///  * **Open on a past week** — `weeklyReportProvider` takes no week argument,
///    so the screen has no way to name an older one.
///  * **Show what you wrote** — reflections are never rendered, exported, or
///    sent to Ada. The app cannot tell "tired today" from something much worse,
///    so it must not amplify, quote or interpret any of it.
class ReportSettingsScreen extends ConsumerWidget {
  const ReportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final on = ref.watch(weeklyReportEnabledProvider);

    // v11 `core-off`: the one toggle, the promise under it, and the list of
    // what it never does.
    return SettingsScaffold(
      title: ReportCopy.settingsTitle,
      children: [
        SetGroup(
          children: [
            SettingsRow(
              label: ReportCopy.settingsToggle,
              toggle: on,
              onToggle: (v) => unawaited(
                ref.read(weeklyReportEnabledProvider.notifier).set(value: v),
              ),
              last: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            ReportCopy.settingsToggleNote,
            style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.65, color: colors.textMed),
          ),
        ),
        const SizedBox(height: 18),
        const GroupLabel(ReportCopy.neverDoesTitle),
        const SetGroup(
          children: [
            SettingsRow(
              icon: Icons.notifications_off_outlined,
              label: ReportCopy.neverNotify,
              sub: ReportCopy.neverNotifySub,
            ),
            SettingsRow(
              icon: Icons.history_toggle_off,
              label: ReportCopy.neverBackBrowse,
              sub: ReportCopy.neverBackBrowseSub,
            ),
            SettingsRow(
              icon: Icons.visibility_off_outlined,
              label: ReportCopy.neverShowWriting,
              sub: ReportCopy.neverShowWritingSub,
              last: true,
            ),
          ],
        ),
      ],
    );
  }
}
