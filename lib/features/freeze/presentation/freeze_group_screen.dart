import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_toggle.dart';
import '../domain/freeze_models.dart';
import '../providers/freeze_controller.dart';
import 'freeze_apps.dart';
import 'sheets/choose_apps_sheet.dart';
import 'widgets/fz_widgets.dart';

enum FreezeGroup { alwaysOpen, neverOpen, distracting }

/// A group page (fz-always, fz-never, fz-distract): the list, then its
/// explanation as a footer beneath it — iOS list anatomy.
class FreezeGroupScreen extends ConsumerWidget {
  const FreezeGroupScreen({super.key, required this.group});

  final FreezeGroup group;

  String get _title => switch (group) {
        FreezeGroup.alwaysOpen => 'Always open',
        FreezeGroup.neverOpen => 'Never open',
        FreezeGroup.distracting => 'Distracting',
      };

  String get _blurb => switch (group) {
        FreezeGroup.alwaysOpen => 'Never frozen, by any frost.',
        FreezeGroup.neverOpen => "Frozen all the time. Thawing doesn't reach these.",
        FreezeGroup.distracting => 'Never frozen. Ada checks in when you open one.',
      };

  String get _owner => switch (group) {
        FreezeGroup.alwaysOpen => 'always',
        FreezeGroup.neverOpen => 'never',
        FreezeGroup.distracting => 'distracting',
      };

  AppSet _setOf(FreezeGroups g) => switch (group) {
        FreezeGroup.alwaysOpen => g.alwaysOpen,
        FreezeGroup.neverOpen => g.neverOpen,
        FreezeGroup.distracting => g.distracting,
      };

  FreezeGroups _with(FreezeGroups g, AppSet s) => switch (group) {
        FreezeGroup.alwaysOpen => g.copyWith(alwaysOpen: s),
        FreezeGroup.neverOpen => g.copyWith(neverOpen: s),
        FreezeGroup.distracting => g.copyWith(distracting: s),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final data = ref.watch(freezeControllerProvider);
    final apps = ref.watch(freezeAppsProvider);
    final controller = ref.read(freezeControllerProvider.notifier);
    final set = _setOf(data.groups);
    final phone = apps.floor.entries.where((e) => e.value == 'phone').map((e) => e.key).firstOrNull;

    void save(AppSet s) {
      // An app lives in one group at a time: Never open and Always open
      // cannot both hold it.
      var g = _with(data.groups, s);
      if (group == FreezeGroup.alwaysOpen) {
        g = g.copyWith(neverOpen: g.neverOpen.copyWith(packages: g.neverOpen.packages.where((p) => !s.packages.contains(p)).toList()));
      } else if (group == FreezeGroup.neverOpen) {
        g = g.copyWith(alwaysOpen: g.alwaysOpen.copyWith(packages: g.alwaysOpen.packages.where((p) => !s.packages.contains(p)).toList()));
      }
      controller.setGroups(g);
    }

    Future<void> add() async {
      final picked = await chooseApps(context, current: set, owner: _owner, allowKeepOnly: false, title: _title);
      if (picked == null) return;
      final keep = [
        ...picked.packages,
        if (phone != null && group == FreezeGroup.alwaysOpen && !picked.packages.contains(phone)) phone,
      ];
      save(picked.copyWith(packages: keep, mode: AppSetMode.freezeThese));
    }

    final rows = <Widget>[
      if (group == FreezeGroup.alwaysOpen && apps.ios)
        const FzListRow(app: FzAppRef('ios.phone', 'Phone'), sub: 'Calls always get through', glyph: 'call'),
      if (group == FreezeGroup.neverOpen && apps.ios)
        _AdultSites(value: data.groups.adultSites, onChanged: (v) => controller.setGroups(data.groups.copyWith(adultSites: v))),
      if (apps.ios)
        FzListRow(
          app: FzAppRef('ios.sel', set.count == 0 ? 'Nothing added yet' : FreezeApps.countLabel(set)),
          sub: 'Chosen in Screen Time',
          glyph: 'hourglass_empty',
        )
      else
        for (final p in set.packages)
          FzListRow(
            app: apps.ref(p),
            glyph: apps.glyphOf(p),
            sub: p == phone && group == FreezeGroup.alwaysOpen ? 'Calls always get through' : null,
            onRemove: p == phone && group == FreezeGroup.alwaysOpen
                ? null
                : () => save(set.copyWith(packages: set.packages.where((x) => x != p).toList())),
          ),
      FzListRow(onAdd: add, last: true, addLabel: apps.ios ? 'Choose apps or sites' : 'Add apps or sites'),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: AppScaffold(
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          children: [
            FzPageHead(title: _title),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(26), boxShadow: colors.cardShadow),
              child: Column(children: rows),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_blurb, style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.38, color: colors.textMed)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Never open → Adult sites (iOS: Screen Time's web content filter).
class _AdultSites extends StatelessWidget {
  const _AdultSites({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        ClipPath(
          clipper: const FzSquircleClipper(),
          child: Container(
            width: 30,
            height: 30,
            color: colors.hilite,
            alignment: Alignment.center,
            child: Text('18+', style: AppText.sans(size: 13, weight: FontWeight.w800, color: colors.textMed)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adult sites', style: AppText.sans(size: 15, color: colors.text)),
                      const SizedBox(height: 1),
                      Text('Every browser · private browsing off', style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
                    ],
                  ),
                ),
                AppToggle(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
