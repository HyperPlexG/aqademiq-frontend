import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ic.dart';
import '../domain/freeze_engine.dart';
import '../domain/freeze_models.dart';
import '../providers/freeze_controller.dart';
import 'freeze_apps.dart';
import 'freeze_group_screen.dart';
import 'sheets/freeze_now_sheet.dart';
import 'sheets/frost_sheets.dart';
import 'thaw_screen.dart';
import 'widgets/fz_widgets.dart';

/// The App freeze hub (fz-hub, fz-hub-empty, fz-hub-standdown): what is frozen
/// now, the frosts, and the three groups. Pushed from Focus's App freeze pill,
/// inside the Focus tab so the bar stays; from Settings it is the full-screen
/// copy at `Routes.freezeHubSettings`.
class FreezeHubScreen extends ConsumerStatefulWidget {
  const FreezeHubScreen({super.key, this.at = Routes.freeze});

  /// Where this hub is mounted. Its group pages are pushed under it, so a hub
  /// on the root navigator never pushes a page into the shell (see
  /// `Routes.freezeHubSettings`).
  final String at;

  @override
  ConsumerState<FreezeHubScreen> createState() => _FreezeHubScreenState();
}

class _FreezeHubScreenState extends ConsumerState<FreezeHubScreen> {
  ThawGrant? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _thaw(String target, String? label) async {
    final grant = await context.push<ThawGrant>(Routes.freezeThaw, extra: ThawRequest(target: target, label: label));
    if (grant == null || !mounted) return;
    _toastTimer?.cancel();
    setState(() => _toast = grant);
    _toastTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// "Until I stop" means there is a stop: the same breath as a thaw, then the
  /// freeze ends for good. Frosts and groups are untouched.
  Future<void> _stopFreezing() async {
    await context.push<ThawGrant>(Routes.freezeThaw, extra: const ThawRequest(target: ThawGrant.allApps, stopNow: true));
  }

  Future<void> _openFrost(Frost f, FreezeData data) async {
    final now = DateTime.now();
    final running = FreezeEngine.active(data, now).any((a) => a.id == f.id);
    if (running) {
      await showActiveFrostSheet(context, f, onThaw: _thaw);
    } else if (f.kind == FrostKind.session) {
      await showFzSheet<void>(context, builder: (_) => _StartSession(frost: f));
    } else {
      await showFrostEditor(context, f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final data = ref.watch(freezeControllerProvider);
    final now = ref.watch(freezeClockProvider).value ?? DateTime.now();
    final apps = ref.watch(freezeAppsProvider);
    final active = FreezeEngine.active(data, now);
    final standingDown = FreezeEngine.standingDown(data, now);
    final frozen = apps.frozenNow(data, now);
    final anyActive = active.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          AppScaffold(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              children: [
                FzPageHead(title: 'App freeze', onAdd: () => unawaited(showNewFrostSheet(context, ref))),
                if (standingDown)
                  _Card(
                    icon: const _ThawBadge(),
                    title: "Everything's thawed",
                    body: data.standdown!.until == null ? 'Until you bring it back.' : FreezeText.backAt(data.standdown!.until!, now),
                    action: 'Bring it back now',
                    onAction: ref.read(freezeControllerProvider.notifier).bringBack,
                  )
                else if (!anyActive)
                  _Card(
                    icon: const AdaMascot(size: 52, cheeks: true, bubbles: 2),
                    title: 'Nothing frozen',
                    body: 'Freeze apps now, or on a schedule.',
                    action: 'Freeze apps',
                    onAction: () => unawaited(showFreezeNowSheet(context)),
                  )
                else ...[
                  FzSec(
                    title: 'Frozen',
                    action: FreezeEngine.deepRunning(data, now) == null ? 'Thaw all' : null,
                    onAction: () => unawaited(_thaw(ThawGrant.allApps, null)),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        if (apps.ios)
                          ..._iosFrozenRow(data, active, now)
                        else if (frozen.isEmpty)
                          for (final a in active) ...[
                            GestureDetector(
                              onTap: () => unawaited(_thaw(ThawGrant.allApps, null)),
                              child: FzCountTile(
                                // Keep only freezes everything but its list;
                                // the kept count is not the frozen count.
                                count: a.apps.keepOnly ? 0 : a.apps.count,
                                frozen: FreezeEngine.grantFor(data, ThawGrant.allApps, now) == null || a.deep,
                              ),
                            ),
                            const SizedBox(width: 18),
                          ]
                        else
                          for (final f in frozen) ...[
                            FzAppTile(
                              app: f.app,
                              state: f.grant == null ? FzTileState.frozen : FzTileState.thawed,
                              minutesLeft: f.grant == null ? null : (f.grant!.until.difference(now).inSeconds / 60).ceil(),
                              progress: f.grant == null ? 0 : _share(f.grant!, now),
                              onTap: f.grant == null ? () => unawaited(_thaw(f.app.id, f.app.name)) : null,
                            ),
                            const SizedBox(width: 18),
                          ],
                      ],
                    ),
                  ),
                  // A Freeze now with no end ("Until I stop"): the way out. Not
                  // for a session's freeze, which ends with the session, and
                  // never for a Deep freeze (those always have an end).
                  if (data.now case FreezeNow(endsAt: null, deep: false, withFocus: false)) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FzLink('Stop freezing', color: colors.accent, weight: FontWeight.w700, onTap: () => unawaited(_stopFreezing())),
                    ),
                  ],
                ],
                if (data.frosts.isEmpty) ...[
                  FzSec(title: 'Student frosts', chevron: true, onTap: () => unawaited(showNewFrostSheet(context, ref))),
                  // Natural height, not a fixed one: a meta line that wraps
                  // must grow the card, not clip it.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final t in frostTemplates()) ...[
                          FzTemplateCard(
                            icon: t.icon,
                            name: t.name,
                            meta: t.meta,
                            width: 150,
                            onTap: () => unawaited(showFrostEditor(context, t.make(ref.read(freezeControllerProvider.notifier)), isNew: true)),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const FzSec(title: 'Frosts'),
                  SizedBox(
                    height: 196,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final f in data.frosts) ...[
                          FzFrostCard(
                            name: f.name,
                            status: FreezeText.status(data, f, now),
                            session: f.kind == FrostKind.session,
                            live: active.any((a) => a.id == f.id),
                            apps: f.apps.keepOnly ? const [] : (apps.ios ? fzTokensOf(ref, f.apps) ?? const [] : apps.of(f.apps)),
                            count: f.apps.count,
                            onTap: () => unawaited(_openFrost(f, data)),
                          ),
                          const SizedBox(width: 14),
                        ],
                      ],
                    ),
                  ),
                ],
                const FzSec(title: 'Groups', top: 12),
                _GroupsRow(data: data, apps: apps, at: widget.at),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: AppScaffold.navClearanceOf(context),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _toast == null
                  ? const SizedBox.shrink()
                  : _ThawedToast(
                      key: ValueKey(_toast!.startedAt),
                      grant: _toast!,
                      onRefreeze: () {
                        ref.read(freezeControllerProvider.notifier).refreeze(_toast!.target);
                        setState(() => _toast = null);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// The most picks the iOS Frozen row draws before "+N": each is a
  /// platform view, so the row stays a handful, not the whole selection.
  static const _iosRowCap = 6;

  /// iOS's Frozen row: each running freeze's picks as tiles, drawn by the
  /// system — frozen ones thaw just that pick, as the shield's Thaw does.
  /// A freeze whose picks can't be drawn (Keep only, below iOS 16, the ids
  /// not in yet) keeps the count tile, which thaws everything.
  List<Widget> _iosFrozenRow(FreezeData data, List<ActiveFreeze> active, DateTime now) {
    final out = <Widget>[];
    final seen = <String>{};
    var hidden = 0;
    for (final a in active) {
      final tiles = fzFrozenTokens(ref, data, a.apps, deep: a.deep, now: now);
      if (tiles == null) {
        out.addAll([
          GestureDetector(
            onTap: () => unawaited(_thaw(ThawGrant.allApps, null)),
            child: FzCountTile(
              // Keep only freezes everything but its list; the kept count is
              // not the frozen count.
              count: a.apps.keepOnly ? 0 : a.apps.count,
              frozen: FreezeEngine.grantFor(data, ThawGrant.allApps, now) == null || a.deep,
            ),
          ),
          const SizedBox(width: 18),
        ]);
        continue;
      }
      for (final f in tiles) {
        if (!seen.add(f.app.id)) continue;
        if (seen.length > _iosRowCap) {
          hidden++;
          continue;
        }
        out.addAll([
          FzAppTile(
            app: f.app,
            state: f.grant == null ? FzTileState.frozen : FzTileState.thawed,
            minutesLeft: f.grant == null ? null : (f.grant!.until.difference(now).inSeconds / 60).ceil(),
            progress: f.grant == null ? 0 : _share(f.grant!, now),
            // iOS never names the pick: the thaw screen shows its icon.
            onTap: f.grant == null ? () => unawaited(_thaw(f.app.id, null)) : null,
          ),
          const SizedBox(width: 18),
        ]);
      }
    }
    if (hidden > 0) out.addAll([FzMoreTile(more: hidden), const SizedBox(width: 18)]);
    return out;
  }

  static double _share(ThawGrant g, DateTime now) {
    final total = g.until.difference(g.startedAt).inSeconds;
    if (total <= 0) return 0;
    return (g.until.difference(now).inSeconds / total).clamp(0, 1).toDouble();
  }
}

class _ThawBadge extends StatelessWidget {
  const _ThawBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: context.colors.accentSoft, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Ic('thaw', size: 28, color: kFzIce),
      );
}

/// The hub's centred card: Nothing frozen / Everything's thawed.
class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.body, required this.action, required this.onAction});

  final Widget icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(34), boxShadow: colors.cardShadow),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 10),
          Text(title, style: AppText.sans(size: 20, weight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.35, color: colors.textMed)),
          const SizedBox(height: 16),
          FzBtn(label: action, onTap: onAction),
        ],
      ),
    );
  }
}

/// Always open · Never open · Distracting (FzGroups).
class _GroupsRow extends StatelessWidget {
  const _GroupsRow({required this.data, required this.apps, required this.at});

  final FreezeData data;
  final FreezeApps apps;

  /// The hub's own path; the group pages go under it.
  final String at;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    String path(FreezeGroup g) => '$at/${FreezeGroupScreen.segmentFor(g)}';
    final groups = [
      ('Always open', data.groups.alwaysOpen, path(FreezeGroup.alwaysOpen)),
      ('Never open', data.groups.neverOpen, path(FreezeGroup.neverOpen)),
      ('Distracting', data.groups.distracting, path(FreezeGroup.distracting)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var gi = 0; gi < groups.length; gi++) ...[
          if (gi > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => unawaited(context.push(groups[gi].$3)),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(30), boxShadow: colors.cardShadow),
                      child: _Cells(set: groups[gi].$2, apps: apps),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(groups[gi].$1, maxLines: 1, style: AppText.sans(size: 17, color: colors.text)),
                  const SizedBox(height: 1),
                  Text(
                    _count(groups[gi].$2.count),
                    style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _count(int n) => n == 1 ? '1 app' : '$n apps';
}

class _Cells extends ConsumerWidget {
  const _Cells({required this.set, required this.apps});

  final AppSet set;
  final FreezeApps apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // iOS: the picks themselves, drawn by the system; the count where they
    // can't be.
    final list = apps.ios ? fzTokensOf(ref, set) ?? const <FzAppRef>[] : apps.of(set);
    final over = list.length > 4;
    Widget cell(int i) {
      Widget inner = const SizedBox.shrink();
      var filled = false;
      if (over && i == 3) {
        inner = Text('+${list.length - 3}', style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text));
      } else if (i < list.length) {
        filled = true;
        inner = LayoutBuilder(
          builder: (_, c) => FzAppIcon(app: list[i], size: c.maxWidth, glyph: apps.glyphOf(list[i].id)),
        );
      } else if (apps.ios && list.isEmpty && i == 0 && set.count > 0) {
        inner = Text('${set.count}', style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text));
      }
      return AspectRatio(
        aspectRatio: 1,
        child: filled
            ? inner
            : ClipPath(
                clipper: const FzSquircleClipper(),
                child: ColoredBox(color: colors.hilite, child: Center(child: inner)),
              ),
      );
    }

    return Column(
      children: [
        Expanded(child: Row(children: [Expanded(child: cell(0)), const SizedBox(width: 9), Expanded(child: cell(1))])),
        const SizedBox(height: 9),
        Expanded(child: Row(children: [Expanded(child: cell(2)), const SizedBox(width: 9), Expanded(child: cell(3))])),
      ],
    );
  }
}

/// "Instagram thawed · refreezes 3:47" + Refreeze (fz-thawed).
class _ThawedToast extends StatelessWidget {
  const _ThawedToast({super.key, required this.grant, required this.onRefreeze});

  final ThawGrant grant;
  final VoidCallback onRefreeze;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final who = grant.label ?? (grant.target == ThawGrant.allApps ? 'Apps' : 'App');
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x38000000), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          const Ic('check_circle:fill', size: 19, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$who thawed · refreezes ${FreezeText.bareClock(grant.until)}',
              style: AppText.sans(size: 15, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
          GestureDetector(
            onTap: onRefreeze,
            child: Text('Refreeze', style: AppText.sans(size: 15, weight: FontWeight.w800, color: const Color(0xFFCFC8FF))),
          ),
        ],
      ),
    );
  }
}

/// Starting a session frost from its card.
class _StartSession extends ConsumerWidget {
  const _StartSession({required this.frost});

  final Frost frost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final length = frost.sessionMinutes == null ? 'until you stop' : 'for ${FreezeText.left(Duration(minutes: frost.sessionMinutes!))}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzSheetTitle('Start ${frost.name}?'),
        FzSheetBody('Freezes ${FreezeApps.countLabel(frost.apps).toLowerCase()} $length.${frost.deep ? ' Deep freeze: no thawing.' : ''}'),
        FzBtn(
          label: 'Start',
          enabled: !frost.apps.isEmpty || frost.apps.keepOnly,
          onTap: () {
            ref.read(freezeControllerProvider.notifier).startSession(frost.id);
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        FzLink(
          'Edit frost',
          weight: FontWeight.w700,
          onTap: () async {
            final root = fzRootContext(context);
            Navigator.of(context).pop();
            await showFrostEditor(root, frost);
          },
        ),
      ],
    );
  }
}
