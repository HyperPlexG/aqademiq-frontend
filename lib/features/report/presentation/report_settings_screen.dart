import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_toggle.dart';
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

    return SettingsScaffold(
      title: ReportCopy.settingsTitle,
      big: true,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.group),
            boxShadow: colors.cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ReportCopy.settingsToggle,
                  style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text),
                ),
              ),
              AppToggle(
                value: on,
                onChanged: (v) => unawaited(
                  ref.read(weeklyReportEnabledProvider.notifier).set(value: v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          ReportCopy.settingsToggleNote,
          style: AppText.sans(size: 12.5, height: 1.45, color: colors.textMed),
        ),
        const SizedBox(height: 26),
        Text(
          ReportCopy.neverDoesTitle,
          style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.group),
            boxShadow: colors.cardShadow,
          ),
          child: Column(
            children: [
              const _NeverRow(
                icon: Icons.notifications_off_outlined,
                title: ReportCopy.neverNotify,
                sub: ReportCopy.neverNotifySub,
              ),
              _Divider(color: colors.border),
              const _NeverRow(
                icon: Icons.history_toggle_off,
                title: ReportCopy.neverBackBrowse,
                sub: ReportCopy.neverBackBrowseSub,
              ),
              _Divider(color: colors.border),
              const _NeverRow(
                icon: Icons.visibility_off_outlined,
                title: ReportCopy.neverShowWriting,
                sub: ReportCopy.neverShowWritingSub,
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 54),
        child: Container(height: 1, color: color),
      );
}

class _NeverRow extends StatelessWidget {
  const _NeverRow({required this.icon, required this.title, required this.sub, this.last = false});

  final IconData icon;
  final String title;
  final String sub;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 15, 16, last ? 16 : 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: colors.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.sans(size: 14.5, weight: FontWeight.w800, color: colors.text)),
                const SizedBox(height: 3),
                Text(sub, style: AppText.sans(size: 12, height: 1.35, color: colors.textMed)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
