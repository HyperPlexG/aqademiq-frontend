import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ice_timer.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../settings/presentation/widgets/settings_scaffold.dart';
import '../data/app_freeze_channel.dart';
import '../domain/freeze_engine.dart';
import '../domain/freeze_models.dart';
import '../providers/freeze_controller.dart';
import 'freeze_apps.dart';
import 'thaw_screen.dart';
import 'widgets/fz_widgets.dart';

/// Settings → App freeze (settings-ice, -android, -off, -standdown). What you
/// change most sits first, then whether it is working: the one honest line
/// about reliability stays above the fold.
class AppFreezeSettingsScreen extends ConsumerWidget {
  const AppFreezeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final data = ref.watch(freezeControllerProvider);
    final now = ref.watch(freezeClockProvider).value ?? DateTime.now();
    final access = ref.watch(freezeAccessProvider).value ?? FreezeAccess.unsupported;
    final ios = ref.watch(freezeAppsProvider).ios;
    final channel = ref.read(appFreezeChannelProvider);
    final controller = ref.read(freezeControllerProvider.notifier);
    final down = FreezeEngine.standingDown(data, now);
    final until = data.standdown?.until;

    final health = !access.authorized ? 'off' : (access.batteryRestricted ? 'warn' : 'ok');
    final (relIcon, relTone, relTitle, relBody) = switch (health) {
      'off' => (
          'cancel',
          colors.warn,
          'Nothing is freezing',
          ios
              ? 'Screen Time access is off. Your frosts are saved and come back when you turn it on.'
              : 'A permission is off. Your frosts are saved and come back when you grant it.',
        ),
      'warn' => ('error_outline', colors.warn, 'Might stop in the background', 'Android can close Aqademiq to save battery. If it does, apps stop freezing.'),
      _ => (
          'check_circle',
          colors.success,
          'Working on this phone',
          ios
              ? 'Screen Time holds your frozen apps, so frosts keep running even when Aqademiq is closed.'
              : 'Aqademiq keeps watch in the background, so frosts keep running when the app is closed.',
        ),
    };
    final frostCount = data.frosts.length;

    return SettingsScaffold(
      title: 'App freeze',
      children: [
        if (down) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Ic('thaw', size: 21, color: kFzIce),
                    const SizedBox(width: 9),
                    Text("Everything's thawed", style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${until == null ? 'Until you bring it back.' : FreezeText.backAt(until, now)} Never open stays frozen.',
                  style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.textMed),
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Bring it back now', onPressed: controller.bringBack),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const GroupLabel('Freezing'),
        SetGroup(
          children: [
            SettingsRow(
              icon: Ic.materialFor('ac_unit'),
              label: 'Frosts & groups',
              value: down ? 'Paused' : (frostCount == 1 ? '1 frost' : '$frostCount frosts'),
              showChevron: true,
              onTap: () => unawaited(context.push(data.setUp ? Routes.freeze : Routes.freezeIntro)),
            ),
            SettingsRow(
              icon: Ic.materialFor('thaw'),
              label: 'Thaw',
              value: '${data.thaw.resistance == ThawResistance.standard ? 'Standard' : 'Increasing'} · ${data.thaw.minutes} min',
              showChevron: true,
              onTap: () => unawaited(context.push(Routes.settingsThaw)),
            ),
            SettingsRow(
              icon: Ic.materialFor('waves'),
              label: 'Thaw everything',
              value: down ? (until == null ? "Until you're back" : 'Until ${FreezeText.clock(until)}') : null,
              sub: down ? null : "For a day, a week, or until you're back",
              showChevron: true,
              last: true,
              onTap: () {
                if (down) {
                  controller.bringBack();
                } else {
                  unawaited(showThawAllSheet(context, ref));
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Reliability'),
        SetGroup(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Ic(relIcon, size: 21, color: relTone),
                      const SizedBox(width: 9),
                      Expanded(child: Text(relTitle, style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text))),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(relBody, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.textMed)),
                  if (health == 'off') ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: ios ? 'Turn Screen Time back on' : 'Grant permissions',
                      onPressed: () => unawaited(context.push(Routes.freezePermission)),
                    ),
                  ],
                ],
              ),
            ),
            SettingsRow(
              icon: Ic.materialFor('refresh'),
              label: 'Check my setup',
              sub: 'Re-checks access and re-applies your frosts',
              showChevron: true,
              last: true,
              onTap: () => unawaited(controller.reapply()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Permissions'),
        SetGroup(
          children: ios
              ? [
                  SettingsRow(
                    icon: Ic.materialFor('hourglass_empty'),
                    label: 'Screen Time',
                    valueWidget: access.authorized
                        ? FzStatus(tone: colors.success, label: 'Allowed')
                        : const FzStatus(tone: kFzDanger, label: 'Off'),
                    showChevron: true,
                    last: true,
                    onTap: () => unawaited(access.authorized ? channel.openSettings('app') : context.push(Routes.freezePermission)),
                  ),
                ]
              : [
                  SettingsRow(
                    icon: Ic.materialFor('query_stats'),
                    label: 'Usage access',
                    valueWidget: _grant(colors, access.usageAccess),
                    showChevron: true,
                    onTap: () => unawaited(channel.openSettings('usage')),
                  ),
                  SettingsRow(
                    icon: Ic.materialFor('layers'),
                    label: 'Appear on top',
                    valueWidget: _grant(colors, access.overlay),
                    showChevron: true,
                    onTap: () => unawaited(channel.openSettings('overlay')),
                  ),
                  SettingsRow(
                    icon: Ic.materialFor('battery_alert'),
                    iconColor: access.batteryRestricted ? colors.warn : null,
                    label: 'Battery',
                    valueWidget: access.batteryRestricted
                        ? FzStatus(tone: colors.warn, label: 'Restricted')
                        : FzStatus(tone: colors.success, label: 'Unrestricted'),
                    showChevron: true,
                    last: true,
                    onTap: () => unawaited(channel.openSettings('battery')),
                  ),
                ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Privacy'),
        SetGroup(
          children: [
            SettingsRow(
              icon: Ic.materialFor('visibility_off'),
              label: 'What we can see',
              sub: ios ? 'Nothing. iOS gives us tokens, not names.' : 'App names, on this phone only. Never sent to us.',
              showChevron: true,
              onTap: () => _promises(context, ios),
            ),
            SettingsRow(
              icon: Ic.materialFor('description'),
              label: 'What we refuse to do for engagement',
              showChevron: true,
              last: true,
              onTap: () => _promises(context, ios),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _grant(AppColors colors, bool on) =>
      on ? FzStatus(tone: colors.success, label: 'Allowed') : const FzStatus(tone: kFzDanger, label: 'Not allowed');

  static void _promises(BuildContext context, bool ios) {
    unawaited(showFzSheet<void>(
      context,
      builder: (sheet) {
        final colors = sheet.colors;
        Widget line(String t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: Ic('check', size: 18, color: colors.success)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.text))),
                ],
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FzSheetTitle('What App freeze never does'),
            const SizedBox(height: 10),
            line(ios ? 'Sees what you pick. Apple gives us tokens, not names.' : 'Sends your app list anywhere. It stays on this phone.'),
            line('Reads your screen, your messages or your browsing.'),
            line('Counts your opens to make you feel bad. A thaw is a number, never a grade.'),
            line('Freezes Phone or emergency calls.'),
            line('Nags you to turn it back on.'),
          ],
        );
      },
    ));
  }
}

/// Thaw everything (settings-thaw-all, -deep): every frost stands down until
/// you're back. A running Deep freeze keeps its deal. Takes the usual breath.
Future<void> showThawAllSheet(BuildContext context, WidgetRef ref) =>
    showFzSheet<void>(context, builder: (_) => const _ThawAll());

class _ThawAll extends ConsumerStatefulWidget {
  const _ThawAll();

  @override
  ConsumerState<_ThawAll> createState() => _ThawAllState();
}

class _ThawAllState extends ConsumerState<_ThawAll> {
  int _pick = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = ref.read(freezeControllerProvider.notifier);
    final deep = c.deepHold;
    final morning = c.tomorrowMorning();
    final now = DateTime.now();
    final until = switch (_pick) {
      0 => morning,
      1 => DateTime(now.year, now.month, now.day + 7, 7),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FzSheetTitle('Thaw everything'),
        const FzSheetBody("Every frost stands down until you're back. Never open stays frozen.", bottom: 14),
        FzPick(icon: 'today', label: 'Just today', sub: 'Back tomorrow at ${FreezeText.clock(morning)}', selected: _pick == 0, onTap: () => setState(() => _pick = 0)),
        const SizedBox(height: 9),
        FzPick(icon: 'date_range', label: 'A week', sub: 'Back in 7 days', selected: _pick == 1, onTap: () => setState(() => _pick = 1)),
        const SizedBox(height: 9),
        FzPick(icon: 'all_inclusive', label: 'Until I bring it back', sub: 'No end date', selected: _pick == 2, onTap: () => setState(() => _pick = 2)),
        if (deep != null && deep.end != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Ic('never_open', size: 20, color: kFzIce),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${deep.name} holds until ${FreezeText.clock(deep.end!)}',
                          style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
                      const SizedBox(height: 1),
                      Text("It's in Deep freeze. After that, it stands down too.",
                          style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.4, color: colors.textMed)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: deep != null ? 'Thaw everything else' : 'Thaw everything',
          onPressed: () {
            final root = fzRootContext(context);
            Navigator.of(context).pop();
            unawaited(root.push<ThawGrant>(
              Routes.freezeThaw,
              extra: ThawRequest(target: ThawGrant.allApps, standDown: true, standDownUntil: until),
            ));
          },
        ),
        const SizedBox(height: 10),
        Text('Takes the usual breath first.',
            textAlign: TextAlign.center, style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.textDim)),
      ],
    );
  }
}

/// Settings → App freeze → Thaw (settings-thaw, settings-thaw-resistance):
/// the wait and the length, previewed as the block screen draws it.
class ThawSettingsScreen extends ConsumerWidget {
  const ThawSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final thaw = ref.watch(freezeControllerProvider).thaw;
    final c = ref.read(freezeControllerProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SettingsScaffold(
      title: 'Thaw',
      children: [
        SizedBox(
          height: 280,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.82, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: 0,
              maxWidth: 220,
              maxHeight: 300,
              child: Container(
                width: 220,
                height: 300,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                decoration: BoxDecoration(
                  gradient: kFrostGround,
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: dark ? const Color(0xFF2C2934) : const Color(0xFFE4E0EC), width: 7),
                ),
                child: Column(
                  children: [
                    Container(width: 62, height: 18, decoration: BoxDecoration(color: const Color(0xFF1A1320), borderRadius: BorderRadius.circular(9))),
                    const SizedBox(height: 24),
                    const IceTimer(progress: 0.3, size: 84),
                    const SizedBox(height: 12),
                    Text('Take a breath.', style: AppText.sans(size: 17, weight: FontWeight.w800, color: kFrostInk)),
                    const SizedBox(height: 3),
                    Text(
                      'Still want Instagram\nin ${thaw.resistance == ThawResistance.standard ? 7 : 17} seconds?',
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 13, height: 1.4, color: kFrostSub),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const GroupLabel('The wait'),
        SetGroup(
          children: [
            SettingsRow(
              icon: Ic.materialFor('shield'),
              label: 'Resistance',
              sub: thaw.resistance == ThawResistance.standard
                  ? 'Standard · 10 seconds, every time'
                  : 'Increasing · 10 more each thaw, up to a minute',
              showChevron: true,
              last: true,
              onTap: () => unawaited(showFzSheet<void>(
                context,
                builder: (sheet) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FzSheetTitle('Resistance'),
                    const SizedBox(height: 10),
                    FzPick(
                      icon: 'shield',
                      label: 'Standard',
                      sub: '10 seconds, every time',
                      selected: thaw.resistance == ThawResistance.standard,
                      onTap: () {
                        c.setThawSettings(thaw.copyWith(resistance: ThawResistance.standard));
                        Navigator.of(sheet).pop();
                      },
                    ),
                    const SizedBox(height: 9),
                    FzPick(
                      icon: 'trend',
                      label: 'Increasing',
                      sub: 'Adds 10 seconds each thaw, up to a minute. Resets each morning.',
                      selected: thaw.resistance == ThawResistance.increasing,
                      onTap: () {
                        c.setThawSettings(thaw.copyWith(resistance: ThawResistance.increasing));
                        Navigator.of(sheet).pop();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Applies to every thaw, including Thaw everything.',
                        textAlign: TextAlign.center,
                        style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: sheet.colors.textDim)),
                  ],
                ),
              )),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const GroupLabel('Thaw length'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(18), boxShadow: colors.cardShadow),
          child: Row(
            children: [
              for (final m in ThawSettings.lengths) ...[
                if (m != ThawSettings.lengths.first) const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => c.setThawSettings(thaw.copyWith(minutes: m)),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: m == thaw.minutes ? colors.ink : colors.bg, borderRadius: BorderRadius.circular(18)),
                      child: Text('$m min',
                          style: AppText.sans(size: 15, weight: FontWeight.w700, color: m == thaw.minutes ? Colors.white : colors.text)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
          child: Text('Picked for you each time you thaw. You can still change it.',
              style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.textMed)),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 4),
            Padding(padding: const EdgeInsets.only(top: 1), child: Ic('never_open', size: 17, color: colors.textDim)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Deep freeze frosts skip all of this. No thawing while they run.',
                  style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.textMed)),
            ),
          ],
        ),
      ],
    );
  }
}
