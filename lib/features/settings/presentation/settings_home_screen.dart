import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/hex_color.dart';
import '../../../core/utils/launch_external.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/tag.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/data_export_repository.dart';
import '../../../data/repositories/tags_repository.dart';
import '../../../services/haptics/haptic_governor.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../shared/icons/app_icon.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../freeze/presentation/widgets/fz_widgets.dart';
import '../../freeze/providers/freeze_controller.dart';
import '../../ice_breakers/ice_breakers_providers.dart';
import '../../report/report_copy.dart';
import '../../report/report_optout.dart';
import '../providers/haptic_settings_provider.dart';
import '../providers/prism_settings_provider.dart';
import '../providers/profile_controller.dart';
import 'sheets/add_tag_sheet.dart';
import 'sheets/appearance_sheet.dart';
import 'sheets/delete_account_dialog.dart';
import 'sheets/rate_sheet.dart';
import 'widgets/settings_scaffold.dart';
import 'widgets/study_tag_mark.dart';

/// FRAMES `settings-home` / `settings-account` (same page, scrolled) — the
/// settings hub (v11 HomeBody).
class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  /// "2 frosts", "Paused", or nothing before App freeze is set up.
  static String? _freezeValue(WidgetRef ref) {
    final data = ref.watch(freezeControllerProvider);
    if (!data.setUp) return null;
    if (data.standdown != null) return 'Paused';
    final n = data.frosts.length;
    return n == 1 ? '1 frost' : '$n frosts';
  }

  /// Haptics (settings-haptics): Off / Essential / Full, in the floating sheet.
  static Future<void> _showHapticsSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(hapticSettingProvider);
    final picked = await showFzSheet<HapticSetting>(
      context,
      builder: (sheet) {
        Widget option(HapticSetting level, String icon, String sub) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: FzPick(
                icon: icon,
                label: level.label,
                sub: sub,
                selected: level == current,
                onTap: () => Navigator.of(sheet).pop(level),
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FzSheetTitle('Haptics'),
            const SizedBox(height: 10),
            option(HapticSetting.off, 'do_not_disturb_on', 'No vibration anywhere'),
            option(HapticSetting.essential, 'vibration', 'Session start, end, and a thaw'),
            option(HapticSetting.full, 'mi:graphic_eq', 'Every tap and toggle'),
          ],
        );
      },
    );
    if (picked != null) ref.read(hapticSettingProvider.notifier).set(picked);
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mode = ref.watch(themeModeProvider);
    final profile = ref.watch(profileControllerProvider);
    final isGuest = ref.watch(isGuestProvider);
    final breakers = ref.watch(iceBreakersProvider);
    final subline = [profile.university, profile.program].where((s) => s != null && s.isNotEmpty).join(' · ');

    return SettingsScaffold(
      title: 'Settings',
      big: true,
      gear: true,
      children: [
        // The profile card → Profile edit (HomeBody).
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: () => unawaited(context.push(Routes.settingsProfile)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), boxShadow: colors.cardShadow),
              child: Row(
                children: [
                  _Avatar(size: 46, emojiSize: 28, colors: colors, avatarIndex: profile.avatarIndex),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                        ),
                        if (subline.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            subline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  AppIcon(Icons.chevron_right, size: 20, color: colors.textDim),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const GroupLabel('Study tags'),
        _TagsCard(
          onAdd: () async {
            final result = await showAddTagSheet(context);
            if (result != null) {
              await ref.read(tagsProvider.notifier).add(
                    label: result.label,
                    colorHex: hexFromColor(result.color),
                  );
            }
          },
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
          child: Text(
            'Ada uses your tags to read your workload and shape your plan.',
            style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.textMed),
          ),
        ),
        const GroupLabel('Preferences'),
        SetGroup(
          children: [
            SettingsRow(label: 'Notifications', icon: Icons.notifications_none, showChevron: true, onTap: () => unawaited(context.push(Routes.settingsNotif))),
            SettingsRow(label: 'Appearance', icon: Icons.brightness_auto, value: _modeLabel(mode), showChevron: true, onTap: () => unawaited(showAppearanceSheet(context))),
            SettingsRow(
              label: 'Haptics',
              icon: Icons.vibration,
              value: ref.watch(hapticSettingProvider).label,
              showChevron: true,
              onTap: () => unawaited(_showHapticsSheet(context, ref)),
            ),
            SettingsRow(label: 'Prism', icon: Icons.graphic_eq, value: ref.watch(prismDefaultModeProvider), showChevron: true, onTap: () => unawaited(context.push(Routes.settingsSounds))),
            SettingsRow(
              label: 'App freeze',
              icon: Icons.ac_unit,
              value: _freezeValue(ref),
              showChevron: true,
              onTap: () => unawaited(context.push(Routes.settingsAppFreeze)),
            ),
            SettingsRow(label: 'What Ada remembers', icon: Icons.psychology_outlined, showChevron: true, onTap: () => unawaited(context.push(Routes.settingsMemories))),
            // A row to its own screen rather than a bare toggle here: the off
            // switch ships with the three promises that make leaving it on
            // safe, and those need somewhere to be read.
            SettingsRow(
              label: ReportCopy.settingsTitle,
              icon: Icons.view_week_outlined,
              value: ref.watch(weeklyReportEnabledProvider) ? '' : 'Off',
              showChevron: true,
              onTap: () => unawaited(context.push(Routes.settingsReport)),
            ),
            SettingsRow(label: 'Calendar import', icon: Icons.calendar_today, showChevron: true, onTap: () => unawaited(context.push(Routes.settingsCalendarImport))),
            SettingsRow(label: 'Reminder import', icon: Icons.format_list_bulleted, showChevron: true, last: true, onTap: () => unawaited(context.push(Routes.settingsReminderImport))),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Account'),
        // A guest has no account, and every row in the signed-in version of this
        // group is wrong for them — one of them destructively so.
        //
        // "Sign out" is the dangerous one. A guest IS their anonymous Supabase
        // session; there are no credentials to sign back in with. Signing out
        // does not log them out of anything, it abandons the only handle on
        // their tasks, subjects and streaks, permanently and with no warning.
        // The row that should be here instead is the one offering to keep that
        // data, which is exactly what onboarding does.
        if (isGuest)
          SetGroup(
            children: [
              SettingsRow(
                label: 'Create account & save progress',
                icon: Icons.person_add_alt,
                showChevron: true,
                last: true,
                onTap: () => unawaited(context.push(Routes.signup)),
              ),
            ],
          )
        else
          SetGroup(
            children: [
              SettingsRow(label: 'Email settings', icon: Icons.mail_outline, showChevron: true, onTap: () => unawaited(context.push(Routes.settingsEmail))),
              SettingsRow(label: 'Download my data', icon: Icons.download_outlined, showChevron: true, onTap: () => unawaited(_downloadMyData(context, ref))),
              SettingsRow(
                label: 'Sign out',
                icon: Icons.logout,
                showChevron: true,
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(Routes.welcome);
                },
              ),
              SettingsRow(
                label: 'Delete account',
                icon: Icons.delete_outline,
                danger: true,
                showChevron: true,
                last: true,
                onTap: () async {
                  final confirmed = await showDeleteAccountDialog(context);
                  if (confirmed != true) return;
                  await ref.read(authRepositoryProvider).deleteAccount();
                  // Tier 4, on the confirm rather than the tap that opened the
                  // dialog. Deliberately unpleasant — this one is irreversible.
                  ref.read(hapticsProvider).destructiveConfirmed();
                  if (context.mounted) context.go(Routes.welcome);
                },
              ),
            ],
          ),
        const SizedBox(height: 20),
        const GroupLabel('About'),
        SetGroup(
          children: [
            SettingsRow(
              label: 'Ice Breakers',
              icon: Icons.play_circle_outline,
              value: '${breakers.watchedCount} of ${breakers.total}',
              showChevron: true,
              onTap: () => unawaited(context.push(Routes.iceBreakers)),
            ),
            SettingsRow(label: 'Feedback & suggestions', icon: Icons.forum_outlined, showChevron: true, onTap: () => unawaited(context.push(Routes.settingsFeedback))),
            SettingsRow(label: 'Rate Aqademiq', icon: Icons.star_outline, showChevron: true, onTap: () => unawaited(showRateSheet(context))),
            SettingsRow(label: 'Privacy Policy', icon: Icons.description, showChevron: true, onTap: () => unawaited(openExternal(context, Uri.parse('https://www.aqademiq.com/privacy-policy')))),
            SettingsRow(label: 'Terms of service', icon: Icons.help_outline, showChevron: true, last: true, onTap: () => unawaited(openExternal(context, Uri.parse('https://www.aqademiq.com/terms-of-use')))),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, required this.emojiSize, required this.colors, this.avatarIndex = 0});
  final double size;
  final double emojiSize;
  final AppColors colors;
  final int avatarIndex;

  @override
  Widget build(BuildContext context) {
    final emoji = kProfileAvatars[avatarIndex.clamp(0, kProfileAvatars.length - 1)];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.24, -0.34), colors: [colors.accentSoft, colors.accent]),
        boxShadow: [BoxShadow(color: colors.accent.alpha8(0x44), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Text(emoji, style: TextStyle(fontSize: emojiSize, height: 1)),
    );
  }
}

class _TagsCard extends ConsumerWidget {
  const _TagsCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), boxShadow: colors.cardShadow),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final t in tags)
            Container(
              height: 36,
              padding: const EdgeInsets.fromLTRB(9, 0, 4, 0),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StudyTagMark(label: t.label, color: hexColor(t.color)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Remove ${t.label}',
                    child: GestureDetector(
                      onTap: () => unawaited(ref.read(tagsProvider.notifier).remove(t.id)),
                      behavior: HitTestBehavior.opaque,
                      // The ✕ sits in a wider hit area than it draws; the
                      // chip's own right padding (10) is made up here.
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Ic('close', size: 16, color: colors.textDim),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onAdd,
              child: CustomPaint(
                painter: _DashedPillPainter(colors.accent.alpha8(0x88)),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Ic('add', size: 18, color: colors.accent),
                      const SizedBox(width: 3),
                      Text('New tag', style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "+ New tag" pill's 1.5 dashed outline (CSS `dashed`).
class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      Radius.circular(size.height / 2),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    const dash = 4.5;
    const gap = 3.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = d + dash < metric.length ? d + dash : metric.length;
        canvas.drawPath(metric.extractPath(d, end), stroke);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter old) => old.color != color;
}

/// A copy of everything this account holds, as a JSON file handed to the share
/// sheet — save it to Files, mail it to yourself, whatever suits (STG-7).
Future<void> _downloadMyData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Preparing your data…')));
  // iPad presents the share sheet as a popover and needs an anchor; iPhone
  // ignores it. See share_sheet.dart for what happens without one.
  final screen = MediaQuery.sizeOf(context);
  final origin = Rect.fromCenter(
    center: Offset(screen.width / 2, screen.height / 2),
    width: 1,
    height: 1,
  );
  try {
    final json = await ref.read(dataExportRepositoryProvider).exportJson();
    messenger.hideCurrentSnackBar();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(utf8.encode(json), mimeType: 'application/json')],
        fileNameOverrides: ['aqademiq-data-$day.json'],
        subject: 'My Aqademiq data',
        sharePositionOrigin: origin,
      ),
    );
  } on Object {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text("Couldn't prepare your data. Try again.")),
      );
  }
}
