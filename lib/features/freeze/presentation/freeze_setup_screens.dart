import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/ic.dart';
import '../data/app_freeze_channel.dart';
import '../providers/freeze_controller.dart';
import 'freeze_apps.dart';
import 'widgets/fz_widgets.dart';

/// First run: what App freeze is (fz-intro), the one ask on iOS
/// (fz-perm-ios), the two grants on Android (fz-perm-android), the battery
/// sheet (fz-perm-battery) and the no-nagging decline (fz-perm-denied).

class _Page extends StatelessWidget {
  const _Page({required this.children, this.center = false});

  final List<Widget> children;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
          child: Column(crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

class FreezeIntroScreen extends StatelessWidget {
  const FreezeIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Page(
      children: [
        Align(alignment: Alignment.centerLeft, child: FzHeadButton(icon: 'back', onTap: () => context.pop())),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: FzIceBlock()),
              const SizedBox(height: 20),
              Text('App freeze',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 34, weight: FontWeight.w800, letterSpacing: -0.4, height: 1.15, color: colors.text)),
              const SizedBox(height: 8),
              Text('Freeze the apps that pull you away.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: colors.textMed)),
              const SizedBox(height: 24),
              const FzClaim(icon: 'ac_unit', title: 'Freeze now, or with a frost', body: 'For this session, or on a schedule.'),
              const SizedBox(height: 16),
              const FzClaim(icon: 'thaw', title: 'Thawing takes a breath', body: 'Wait 10 seconds. Get 2–15 minutes.'),
              const SizedBox(height: 16),
              const FzClaim(icon: 'visibility_off', title: 'We never see your picks', body: 'Your list stays on this phone.'),
            ],
          ),
        ),
        FzBtn(label: 'Set up App freeze', onTap: () => unawaited(context.pushReplacement(Routes.freezePermission))),
        const SizedBox(height: 12),
        FzLink('Not now', onTap: () => context.pop()),
      ],
    );
  }
}

/// The permission step. Shared with onboarding through [FreezeGrants].
class FreezePermissionScreen extends ConsumerStatefulWidget {
  const FreezePermissionScreen({super.key});

  @override
  ConsumerState<FreezePermissionScreen> createState() => _FreezePermissionScreenState();
}

class _FreezePermissionScreenState extends ConsumerState<FreezePermissionScreen> with WidgetsBindingObserver {
  FreezeAccess _access = FreezeAccess.unsupported;
  bool _asking = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from system Settings: the grants may have changed.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final access = await ref.read(appFreezeChannelProvider).status();
    if (!mounted) return;
    setState(() => _access = access);
    if (!ref.read(freezeAppsProvider).ios && access.authorized) await _finish(access);
  }

  Future<void> _finish(FreezeAccess access) async {
    if (_done) return;
    _done = true;
    final c = ref.read(freezeControllerProvider.notifier)..markSetUp();
    final floor = await ref.read(appFreezeChannelProvider).floorApps();
    c.seedFloor(floor);
    ref
      ..invalidate(freezeAccessProvider)
      ..invalidate(floorAppsProvider);
    if (!mounted) return;
    if (access.batteryRestricted) await showBatterySheet(context, ref);
    if (mounted) unawaited(context.pushReplacement(Routes.freeze));
  }

  Future<void> _continueIos() async {
    if (_asking) return;
    setState(() => _asking = true);
    final ok = await ref.read(appFreezeChannelProvider).requestAuthorization();
    if (!mounted) return;
    setState(() => _asking = false);
    if (ok) {
      await _finish(await ref.read(appFreezeChannelProvider).status());
    } else {
      unawaited(context.pushReplacement(Routes.freezeDenied));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ios = ref.watch(freezeAppsProvider).ios;
    final channel = ref.read(appFreezeChannelProvider);
    return _Page(
      children: [
        Align(alignment: Alignment.centerLeft, child: FzHeadButton(icon: 'back', onTap: () => context.pop())),
        const SizedBox(height: 16),
        Text(
          ios ? 'Screen Time does\nthe freezing' : "Two permissions,\nthen you're set",
          style: AppText.sans(size: 28, weight: FontWeight.w800, letterSpacing: -0.3, height: 1.2, color: colors.text),
        ),
        const SizedBox(height: 8),
        Text(
          ios ? 'iOS asks once. Your picks stay on this phone.' : "Grant both in Settings. We'll bring you back.",
          style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
        ),
        const SizedBox(height: 22),
        if (ios) ...[
          FzClaim(icon: 'check_circle_outline', title: 'What it can do', body: 'Freeze and unfreeze your picks on time.', tone: colors.success),
          const SizedBox(height: 16),
          FzClaim(icon: 'hidden', title: "What it can't do", body: 'See, log or sync your picks.', tone: colors.textMed),
          const SizedBox(height: 16),
          const FzClaim(icon: 'schedule', title: 'It keeps time without us', body: 'Frosts run even when Aqademiq is closed.'),
        ] else ...[
          FreezeGrants(access: _access, onGrant: (t) => unawaited(channel.openSettings(t))),
          const SizedBox(height: 14),
          FzWell(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Ic('shield', size: 17, color: colors.success),
                const SizedBox(width: 9),
                Expanded(child: Text('We never read your screen.', style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.text))),
              ],
            ),
          ),
        ],
        const Spacer(),
        if (ios) ...[
          FzBtn(label: _asking ? 'Waiting for iOS…' : 'Continue', enabled: !_asking, onTap: _continueIos),
          const SizedBox(height: 12),
          Text('iOS will ask on the next screen',
              textAlign: TextAlign.center, style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim)),
        ] else
          FzBtn(
            label: 'Open system settings',
            onTap: () => unawaited(channel.openSettings(_access.usageAccess ? 'overlay' : 'usage')),
          ),
      ],
    );
  }
}

/// Android's two grants, ticked as they land (fz-perm-android, ObGrants).
class FreezeGrants extends StatelessWidget {
  const FreezeGrants({super.key, required this.access, required this.onGrant});

  final FreezeAccess access;
  final ValueChanged<String> onGrant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final grants = [
      ('Usage access', 'Shows which app is open.', access.usageAccess, 'usage'),
      ('Display over other apps', 'Puts the frozen screen on top.', access.overlay, 'overlay'),
    ];
    return Column(
      children: [
        for (var i = 0; i < grants.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          GestureDetector(
            onTap: grants[i].$3 ? null : () => onGrant(grants[i].$4),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: grants[i].$3 ? colors.accentSoft : colors.bg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: grants[i].$3 ? colors.accent.withValues(alpha: 0.33) : Colors.transparent, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: grants[i].$3 ? colors.accent : colors.surface,
                      shape: BoxShape.circle,
                      boxShadow: grants[i].$3 ? null : colors.cardShadow,
                    ),
                    child: grants[i].$3
                        ? const Ic('check', size: 18, color: Colors.white)
                        : Text('${i + 1}', style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grants[i].$1, style: AppText.sans(size: 17, color: colors.text)),
                        const SizedBox(height: 1),
                        Text(grants[i].$2, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.33, color: colors.textMed)),
                      ],
                    ),
                  ),
                  if (!grants[i].$3) Text('Grant', style: AppText.sans(size: 17, color: colors.accent)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The battery sheet (fz-perm-battery). Some phones close background apps;
/// frosts stop with them.
Future<void> showBatterySheet(BuildContext context, WidgetRef ref) {
  return showFzSheet<void>(
    context,
    builder: (sheet) {
      final colors = sheet.colors;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FzSheetTitle('Your battery manager can stop App freeze'),
          const FzSheetBody('Some phones close background apps. Frosts stop with them.', bottom: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(26)),
            child: Row(
              children: [
                Ic('battery', size: 22, color: colors.warn),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aqademiq · Battery', style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
                      const SizedBox(height: 1),
                      Text('Restricted by your phone', style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: colors.warn, borderRadius: BorderRadius.circular(100)),
                  child: Text('FIX', style: AppText.sans(size: 11, weight: FontWeight.w800, letterSpacing: 0.44, color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FzBtn(
            label: 'Open battery settings',
            onTap: () {
              unawaited(ref.read(appFreezeChannelProvider).openSettings('battery'));
              Navigator.of(sheet).pop();
            },
          ),
          const SizedBox(height: 8),
          FzLink('Leave it as it is', onTap: () => Navigator.of(sheet).pop()),
        ],
      );
    },
  );
}

class FreezeDeniedScreen extends ConsumerWidget {
  const FreezeDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final ios = ref.watch(freezeAppsProvider).ios;
    return _Page(
      children: [
        Align(alignment: Alignment.centerLeft, child: FzHeadButton(icon: 'back', onTap: () => context.pop())),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AdaMascot(size: 64, toneIndex: 1, melt: 0.25, expr: AdaExpr.sad, bubbles: 1),
              const SizedBox(height: 16),
              Text('App freeze is off', style: AppText.sans(size: 28, weight: FontWeight.w800, letterSpacing: -0.3, color: colors.text)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  ios ? 'Nothing freezes without Screen Time.' : 'Nothing freezes without both permissions.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
                ),
              ),
            ],
          ),
        ),
        FzBtn(
          label: 'Turn it on',
          ghost: true,
          icon: 'freeze',
          onTap: () async {
            final channel = ref.read(appFreezeChannelProvider);
            if (ios && await channel.requestAuthorization()) {
              ref.read(freezeControllerProvider.notifier).markSetUp();
              if (context.mounted) unawaited(context.pushReplacement(Routes.freeze));
              return;
            }
            // Neither OS asks twice: Settings is the way back.
            await channel.openSettings(ios ? 'app' : 'usage');
          },
        ),
        const SizedBox(height: 12),
        Text('Find it anytime in Settings → App freeze.',
            textAlign: TextAlign.center, style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.textDim)),
      ],
    );
  }
}
