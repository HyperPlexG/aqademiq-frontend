import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/icons/app_icon.dart';
import '../../../../shared/widgets/ic.dart';
import '../../data/app_freeze_channel.dart';
import '../../domain/freeze_models.dart';
import '../../providers/freeze_controller.dart';
import '../freeze_apps.dart';
import '../widgets/fz_widgets.dart';

/// Choose apps (fz-select, fz-select-keep, fz-picker).
///
/// Android lists what is installed and suggests the usual suspects. iOS hands
/// the choice to Apple's picker — "We never see what you pick" — and gets back
/// only a count. Both offer Freeze these / Keep only these.
///
/// [owner] names the set (a frost id, `now`, `always`…) so an iOS selection is
/// saved under a stable id. Returns null when dismissed.
Future<AppSet?> chooseApps(
  BuildContext context, {
  required AppSet current,
  required String owner,
  bool allowKeepOnly = true,
  String title = 'Selected',
}) {
  return showFzSheet<AppSet>(
    context,
    builder: (_) => _ChooseApps(current: current, owner: owner, allowKeepOnly: allowKeepOnly, title: title),
  );
}

class _ChooseApps extends ConsumerStatefulWidget {
  const _ChooseApps({required this.current, required this.owner, required this.allowKeepOnly, required this.title});

  final AppSet current;
  final String owner;
  final bool allowKeepOnly;
  final String title;

  @override
  ConsumerState<_ChooseApps> createState() => _ChooseAppsState();
}

class _ChooseAppsState extends ConsumerState<_ChooseApps> {
  late AppSet _set = widget.current;
  bool _picking = false;

  Future<void> _pickIos() async {
    if (_picking) return;
    setState(() => _picking = true);
    // Its own selection, never a shared one: re-picking for one frost must
    // not silently rewrite every set that came from the same pick.
    final id = 'sel-${widget.owner}';
    final result = await ref.read(appFreezeChannelProvider).pickApps(
          selectionId: id,
          title: _set.keepOnly ? 'Keep only these' : 'Choose what freezes',
        );
    if (!mounted) return;
    setState(() {
      _picking = false;
      if (result != null) _set = _set.copyWith(iosSelection: result.selectionId, iosCount: result.count);
    });
  }

  Future<void> _addAndroid() async {
    final picked = await showFzSheet<List<String>>(
      context,
      builder: (_) => _AppList(selected: _set.packages.toSet()),
    );
    if (picked == null || !mounted) return;
    setState(() => _set = _set.copyWith(packages: picked));
  }

  void _toggle(String package) {
    final list = [..._set.packages];
    if (!list.remove(package)) list.add(package);
    setState(() => _set = _set.copyWith(packages: list));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final apps = ref.watch(freezeAppsProvider);
    final installed = ref.watch(installedAppsProvider).value ?? const <DeviceApp>[];
    final installedSet = {for (final a in installed) a.package};
    final suggestions = [
      for (final s in FzKnownApps.suggested)
        for (final p in s.packages)
          if (installedSet.contains(p) && !_set.packages.contains(p)) FzAppRef(p, s.name),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzSheetHead(
          title: widget.title,
          right: Semantics(
            button: true,
            label: 'Done',
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(_set),
              child: Container(
                width: kFzHeadButton,
                height: kFzHeadButton,
                decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Ic('check', color: Colors.white),
              ),
            ),
          ),
        ),
        if (widget.allowKeepOnly) ...[
          FzSeg(
            options: const ['Freeze these', 'Keep only these'],
            index: _set.keepOnly ? 1 : 0,
            onChanged: (i) => setState(() => _set = _set.copyWith(mode: i == 1 ? AppSetMode.keepOnly : AppSetMode.freezeThese)),
          ),
          const SizedBox(height: 12),
        ],
        if (_set.keepOnly) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(26)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Ic('freeze', size: 18, color: kFzIce),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Everything else freezes, new apps too.',
                    style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.5, color: colors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (apps.ios)
          _IosPick(count: _set.iosCount, keepOnly: _set.keepOnly, busy: _picking, onTap: _pickIos)
        else
          FzWell(
            child: Column(
              children: [
                FzListRow(onAdd: _addAndroid, last: _set.packages.isEmpty),
                for (var i = 0; i < _set.packages.length; i++)
                  FzListRow(
                    app: apps.ref(_set.packages[i]),
                    glyph: apps.glyphOf(_set.packages[i]),
                    last: i == _set.packages.length - 1,
                    onRemove: () => _toggle(_set.packages[i]),
                  ),
              ],
            ),
          ),
        if (!apps.ios && !_set.keepOnly && suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
            child: Text('Suggested', style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
          ),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            runSpacing: 14,
            children: [
              for (final s in suggestions.take(8))
                SizedBox(
                  width: 76,
                  child: GestureDetector(
                    onTap: () => _toggle(s.id),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            FzAppIcon(app: s, size: 60),
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.surface, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: const Ic('add', size: 15, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(s.name, style: AppText.sans(size: 13, color: colors.textMed)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// iOS: one row that opens Apple's picker, and the promise beside it.
class _IosPick extends StatelessWidget {
  const _IosPick({required this.count, required this.keepOnly, required this.busy, required this.onTap});

  final int count;
  final bool keepOnly;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = count == 0 ? 'Nothing picked yet' : (count == 1 ? '1 picked' : '$count picked');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzField(
          label: keepOnly ? 'Keep open' : 'Choose what freezes',
          onTap: busy ? null : onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
              Ic('chevron_right', size: 20, color: colors.textDim),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Row(
            children: [
              Ic('hidden', size: 16, color: colors.textMed),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Apple shows the list. We never see what you pick.',
                  style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Android's full list of installed apps, searchable, ticked in place.
class _AppList extends ConsumerStatefulWidget {
  const _AppList({required this.selected});

  final Set<String> selected;

  @override
  ConsumerState<_AppList> createState() => _AppListState();
}

class _AppListState extends ConsumerState<_AppList> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final installed = ref.watch(installedAppsProvider);
    final apps = ref.watch(freezeAppsProvider);
    final floor = apps.floor.keys.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzSheetHead(
          title: 'All apps',
          back: true,
          right: FzHeadPill(label: 'Done', onTap: () => Navigator.of(context).pop(_selected.toList())),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(22)),
          child: Row(
            children: [
              AppIcon(Icons.search, size: 20, color: colors.textMed),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Search',
                    hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.55,
          child: installed.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => Center(child: Text("Couldn't read your apps.", style: AppText.sans(size: 15, color: colors.textMed))),
            data: (list) {
              final shown = [
                for (final a in list)
                  if (!floor.contains(a.package) && (_query.isEmpty || a.label.toLowerCase().contains(_query))) a,
              ];
              if (shown.isEmpty) {
                return Center(child: Text('No apps match.', style: AppText.sans(size: 15, color: colors.textMed)));
              }
              return ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final a = shown[i];
                  final on = _selected.contains(a.package);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      if (on) {
                        _selected.remove(a.package);
                      } else {
                        _selected.add(a.package);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          FzAppIcon(app: FzAppRef(a.package, a.label), size: 36),
                          const SizedBox(width: 14),
                          Expanded(child: Text(a.label, style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text))),
                          AppIcon(on ? Icons.check_circle : Icons.radio_button_unchecked, color: on ? colors.accent : colors.textDim),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
