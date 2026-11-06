import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../freeze/data/app_freeze_channel.dart';
import '../../freeze/domain/freeze_engine.dart';
import '../../freeze/domain/freeze_models.dart';
import '../../freeze/presentation/freeze_apps.dart';
import '../../freeze/presentation/freeze_setup_screens.dart';
import '../../freeze/presentation/sheets/choose_apps_sheet.dart';
import '../../freeze/presentation/widgets/fz_widgets.dart';
import '../../freeze/providers/freeze_controller.dart';
import '../providers/onboarding_controller.dart';
import 'ob_source_screen.dart';
import 'widgets/onboarding_scaffold.dart';

/// The frosts this student's study hours make (ob-freeze): Wellness time on
/// the days left over, then Study hours.
List<Frost> _draftFrosts(OnboardingDraft d) =>
    onboardingFrosts(studyDays: d.studyDays, fromMinute: d.studyFromMin, untilMinute: d.studyUntilMin);

/// ob-freeze-ios / -android / -custom / -all — "Freeze what pulls you away".
/// iOS asks once for Screen Time; Android needs two grants in Settings.
class ObFreezeScreen extends ConsumerStatefulWidget {
  const ObFreezeScreen({super.key});

  @override
  ConsumerState<ObFreezeScreen> createState() => _ObFreezeScreenState();
}

class _ObFreezeScreenState extends ConsumerState<ObFreezeScreen> with WidgetsBindingObserver {
  FreezeAccess _access = FreezeAccess.unsupported;
  bool _asking = false;
  bool _moved = false;

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
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final access = await ref.read(appFreezeChannelProvider).status();
    if (!mounted) return;
    setState(() => _access = access);
    // Android: back from Settings with both grants — straight on to the apps.
    // Only while this step is on top: a resume while Prism or the loading
    // screen is showing must not push the apps step over them.
    final onTop = ModalRoute.of(context)?.isCurrent ?? false;
    if (!ref.read(freezeAppsProvider).ios && access.authorized && onTop) _toApps();
  }

  void _toApps() {
    if (_moved) return;
    _moved = true;
    unawaited(context.push(Routes.obApps).then((_) => _moved = false));
  }

  Future<void> _turnOnIos() async {
    if (_asking) return;
    setState(() => _asking = true);
    final ok = await ref.read(appFreezeChannelProvider).requestAuthorization();
    if (!mounted) return;
    setState(() => _asking = false);
    // Declined: no nagging — onboarding simply carries on without it.
    unawaited(context.push(ok ? Routes.obApps : Routes.obPrism));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ios = ref.watch(freezeAppsProvider).ios;
    final draft = ref.watch(onboardingProvider);
    final frosts = _draftFrosts(draft);
    final ready = frosts.length > 1 ? 'Two frosts are ready.' : 'One frost is ready.';
    final channel = ref.read(appFreezeChannelProvider);

    return OnboardingScaffold(
      activeStep: 8,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Freeze what\npulls you away', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 4),
          Text(
            ios ? '$ready iOS asks once for Screen Time to run them.' : '$ready Android needs two permissions to run them.',
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.6, color: colors.textMed),
          ),
          const SizedBox(height: 18),
          FzWell(
            child: Column(
              children: [
                for (var i = 0; i < frosts.length; i++)
                  Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: colors.border))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(frosts[i].name, style: AppText.sans(size: 17, color: colors.text)),
                              const SizedBox(height: 1),
                              Text(
                                '${_daysShort(frosts[i].days)} · ${FreezeText.span(frosts[i])}',
                                style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                              ),
                            ],
                          ),
                        ),
                        const FzTrigger(live: true, size: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (ios) ...[
            FzClaim(icon: 'hidden', title: 'We never see your picks', body: 'Your list stays on this phone.', tone: colors.textMed),
            const SizedBox(height: 16),
            const FzClaim(icon: 'schedule', title: 'Runs without us', body: 'Frosts start even when Aqademiq is closed.'),
          ] else ...[
            FreezeGrants(access: _access, onGrant: (t) => unawaited(channel.openSettings(t))),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Ic('shield', size: 17, color: colors.success),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('We never read your screen.', style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.textMed)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: ios ? (_asking ? 'Waiting for iOS…' : 'Turn on App freeze') : (_access.authorized ? 'Continue →' : 'Open system settings'),
            enabled: !_asking,
            onPressed: () {
              if (ios) {
                unawaited(_turnOnIos());
              } else if (_access.authorized) {
                _toApps();
              } else {
                unawaited(channel.openSettings(_access.usageAccess ? 'overlay' : 'usage'));
              }
            },
          ),
          ObLink(label: 'Not now', onTap: () => unawaited(context.push(Routes.obPrism))),
        ],
      ),
    );
  }

  /// "Mon–Fri", "Sat, Sun" — the onboarding list's day label (obDays).
  static String _daysShort(Set<int> days) {
    final s = days.toList()..sort();
    if (s.length > 1 && s.last - s.first == s.length - 1) {
      return '${FreezeText.day3[s.first - 1]}–${FreezeText.day3[s.last - 1]}';
    }
    return s.map((d) => FreezeText.day3[d - 1]).join(', ');
  }
}

/// ob-apps-ios / ob-apps-android — "Pick what freezes". iOS: Apple's picker
/// under our line ("We never see what you pick."). Android: the usual
/// suspects, pre-ticked.
class ObAppsScreen extends ConsumerStatefulWidget {
  const ObAppsScreen({super.key});

  @override
  ConsumerState<ObAppsScreen> createState() => _ObAppsScreenState();
}

class _ObAppsScreenState extends ConsumerState<ObAppsScreen> {
  /// Android: ticked packages. Seeded from the installed suggestions.
  Set<String>? _ticked;
  AppSet _ios = AppSet.empty;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(freezeAppsProvider).ios) {
      // Apple's sheet is the screen: open it straight away.
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_pickIos()));
    }
  }

  Future<void> _pickIos() async {
    if (_picking) return;
    setState(() => _picking = true);
    final r = await ref.read(appFreezeChannelProvider).pickApps(selectionId: 'sel-ob', title: 'Choose what freezes');
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (r != null) _ios = AppSet(iosSelection: r.selectionId, iosCount: r.count);
    });
  }

  void _finish(AppSet apps) {
    final draft = ref.read(onboardingProvider);
    final freeze = ref.read(freezeControllerProvider.notifier);
    if (!apps.isEmpty) freeze.adoptOnboardingFrosts(_draftFrosts(draft), apps: apps);
    final floor = ref.read(floorAppsProvider).value;
    if (floor != null) freeze.seedFloor(floor);
    unawaited(context.push(Routes.obPrism));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final apps = ref.watch(freezeAppsProvider);
    final installed = ref.watch(installedAppsProvider).value ?? const <DeviceApp>[];
    final have = {for (final a in installed) a.package};
    final suggestions = [
      for (final s in FzKnownApps.suggested)
        if (s.packages.where(have.contains).firstOrNull case final String p) (ref: FzAppRef(p, s.name), on: FzKnownApps.preTicked.contains(s.name)),
    ];
    _ticked ??= installed.isEmpty ? null : {for (final s in suggestions) if (s.on) s.ref.id};
    final ticked = _ticked ?? const <String>{};
    final floorNames = apps.ios ? const ['Phone', 'Messages', 'Maps', 'Wallet'] : _floorNames(apps);

    final floorCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ALWAYS OPEN · NEVER FROZEN',
              style: AppText.sans(size: 11, weight: FontWeight.w800, letterSpacing: 0.99, color: colors.accent)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in floorNames)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(100)),
                  child: Text(n, style: AppText.sans(size: 13, weight: FontWeight.w700, color: colors.text)),
                ),
            ],
          ),
        ],
      ),
    );

    if (apps.ios) {
      return OnboardingScaffold(
        activeStep: 9,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose what freezes.', style: AppText.sans(size: 28, weight: FontWeight.w800, letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text('We never see what you pick.', style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: colors.textMed)),
            const SizedBox(height: 14),
            floorCard,
            const SizedBox(height: 14),
            FzField(
              label: 'Choose in Screen Time',
              onTap: _picking ? null : () => unawaited(_pickIos()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_ios.isEmpty ? 'Nothing yet' : FreezeApps.countLabel(_ios),
                      style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
                  Ic('chevron_right', size: 20, color: colors.textDim),
                ],
              ),
            ),
          ],
        ),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: _ios.isEmpty ? 'Choose apps' : 'Freeze ${FreezeApps.countLabel(_ios)}',
              onPressed: () {
                if (_ios.isEmpty) {
                  unawaited(_pickIos());
                } else {
                  _finish(_ios);
                }
              },
            ),
            ObLink(label: 'Not now', onTap: () => unawaited(context.push(Routes.obPrism))),
          ],
        ),
      );
    }

    return OnboardingScaffold(
      activeStep: 9,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pick what\nfreezes', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 4),
          Text('We ticked the usual suspects. Tap to change.',
              style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.6, color: colors.textMed)),
          const SizedBox(height: 20),
          if (suggestions.isNotEmpty)
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 18,
              childAspectRatio: 0.78,
              children: [
                for (final s in suggestions) _Tile(app: s.ref, on: ticked.contains(s.ref.id), onTap: () => setState(() {
                      final next = {...ticked};
                      if (!next.remove(s.ref.id)) next.add(s.ref.id);
                      _ticked = next;
                    })),
                for (final p in ticked.where((p) => !suggestions.any((s) => s.ref.id == p)))
                  _Tile(app: apps.ref(p), on: true, onTap: () => setState(() => _ticked = {...ticked}..remove(p))),
              ],
            ),
          const SizedBox(height: 18),
          FzField(
            label: 'All apps',
            onTap: () async {
              final picked = await chooseApps(
                context,
                current: AppSet(packages: ticked.toList()),
                owner: 'ob',
                allowKeepOnly: false,
                title: 'Pick what freezes',
              );
              if (picked != null && mounted) setState(() => _ticked = picked.packages.toSet());
            },
            trailing: Ic('chevron_right', size: 20, color: colors.textDim),
          ),
          const SizedBox(height: 10),
          floorCard,
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: ticked.isEmpty ? 'Freeze nothing yet' : 'Freeze ${ticked.length == 1 ? '1 app' : '${ticked.length} apps'}',
            onPressed: () => _finish(AppSet(packages: ticked.toList())),
          ),
          ObLink(label: 'Not now', onTap: () => unawaited(context.push(Routes.obPrism))),
        ],
      ),
    );
  }

  static List<String> _floorNames(FreezeApps apps) {
    final roles = apps.floor.values.toSet();
    final names = [
      for (final r in const ['phone', 'messages', 'maps', 'wallet'])
        if (roles.contains(r)) FzKnownApps.floorNames[r]!,
    ];
    return names.isEmpty ? const ['Phone', 'Messages'] : names;
  }
}

/// A pre-ticked app (ObAppTile): its icon with a tick badge, dimmed when off.
class _Tile extends StatelessWidget {
  const _Tile({required this.app, required this.on, required this.onTap});

  final FzAppRef app;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: on,
      label: app.name,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(opacity: on ? 1 : 0.5, child: FzAppIcon(app: app, size: 60)),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: on ? colors.accent : colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: on ? colors.surface : colors.border, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: on ? const Ic('check', size: 15, color: Colors.white) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              app.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 13, color: on ? colors.text : colors.textMed),
            ),
          ],
        ),
      ),
    );
  }
}
