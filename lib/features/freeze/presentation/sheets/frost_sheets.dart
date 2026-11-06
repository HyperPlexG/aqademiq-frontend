import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';
import '../../domain/freeze_engine.dart';
import '../../domain/freeze_models.dart';
import '../../providers/freeze_controller.dart';
import '../freeze_apps.dart';
import '../widgets/fz_widgets.dart';
import 'choose_apps_sheet.dart';
import 'freeze_now_sheet.dart';

/// The frost sheets: New frost (fz-new), the editor (fz-edit, fz-edit-time),
/// a running frost (fz-active), End early (fz-end) and Deep freeze holds
/// (fz-deep).

/// The Student frosts (FZ_TEMPLATES).
List<({String icon, String name, String meta, Frost Function(FreezeController c) make})> frostTemplates() => [
      (
        icon: 'school',
        name: 'Lecture hours',
        meta: '9 AM – 1 PM · Mon–Fri',
        make: (c) => c.newFrost(name: 'Lecture hours'),
      ),
      (
        icon: 'task_exam',
        name: 'Exam week',
        meta: 'All day · 7 days',
        make: (c) {
          final t = DateTime.now();
          final today = DateTime(t.year, t.month, t.day);
          return c.newFrost(name: 'Exam week').copyWith(
                days: {1, 2, 3, 4, 5, 6, 7},
                startMinute: 0,
                endMinute: 1440,
                fromDay: today,
                untilDay: DateTime(today.year, today.month, today.day + 6),
                deep: true,
              );
        },
      ),
      (
        icon: 'center_focus_strong',
        name: 'Deep work',
        meta: '2 hr session',
        make: (c) => c.newFrost(name: 'Deep work', kind: FrostKind.session).copyWith(sessionMinutes: 120),
      ),
      (
        icon: 'bedtime',
        name: 'Wind down',
        meta: '10 PM – 7 AM · Daily',
        make: (c) => c.newFrost(name: 'Wind down').copyWith(days: {1, 2, 3, 4, 5, 6, 7}, startMinute: 22 * 60, endMinute: 7 * 60),
      ),
    ];

/// New frost: Session or Schedule, or start from a Student frost. Opens the
/// editor on the new frost; nothing is saved until the editor's Save.
Future<void> showNewFrostSheet(BuildContext context, WidgetRef ref) async {
  final frost = await showFzSheet<Frost>(context, builder: (_) => const _NewFrost());
  if (frost == null || !context.mounted) return;
  await showFrostEditor(context, frost, isNew: true);
}

class _NewFrost extends ConsumerWidget {
  const _NewFrost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final c = ref.read(freezeControllerProvider.notifier);
    Widget kind(String icon, String title, String sub, FrostKind k) => Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(c.newFrost(name: k == FrostKind.session ? 'Session' : 'Schedule', kind: k)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 132),
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(30)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ic(icon, size: 26, color: colors.accent),
                  const SizedBox(height: 40),
                  Text(title, style: AppText.sans(size: 20, weight: FontWeight.w700, color: colors.text)),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.3, color: colors.textMed)),
                ],
              ),
            ),
          ),
        );
    final templates = frostTemplates();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FzSheetHead(title: 'New frost', bottom: 18),
        Row(
          children: [
            kind('timer', 'Session', 'e.g. 30m or until I stop', FrostKind.session),
            const SizedBox(width: 8),
            kind('calendar_month', 'Schedule', 'e.g. 9–5, weekdays', FrostKind.schedule),
          ],
        ),
        const SizedBox(height: 26),
        Text('Student frosts', style: AppText.sans(size: 20, weight: FontWeight.w700, color: colors.text)),
        const SizedBox(height: 2),
        Text('Start from one. Change anything.', style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
        const SizedBox(height: 14),
        // Two columns of natural height: a fixed aspect ratio clipped the
        // cards once their two-line meta wrapped.
        LayoutBuilder(
          builder: (_, box) {
            final w = (box.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in templates)
                  SizedBox(
                    width: w,
                    child: FzTemplateCard(
                      icon: t.icon,
                      name: t.name,
                      meta: t.meta,
                      well: true,
                      onTap: () => Navigator.of(context).pop(t.make(c)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---- the editor -------------------------------------------------------------

Future<void> showFrostEditor(BuildContext context, Frost frost, {bool isNew = false}) =>
    showFzSheet<void>(context, builder: (_) => _FrostEditor(initial: frost, isNew: isNew));

class _FrostEditor extends ConsumerStatefulWidget {
  const _FrostEditor({required this.initial, required this.isNew});

  final Frost initial;
  final bool isNew;

  @override
  ConsumerState<_FrostEditor> createState() => _FrostEditorState();
}

class _FrostEditorState extends ConsumerState<_FrostEditor> {
  late Frost _f = widget.initial;

  static const _lengths = <int?>[30, 60, 120, null];

  String _lengthLabel(int? m) => switch (m) {
        null => 'Until I stop',
        30 => '30 min',
        60 => '1 hr',
        final int v => '${v ~/ 60} hr',
      };

  Future<void> _pickTime({required bool start}) async {
    final picked = await showFrostTimeDialog(
      context,
      title: start ? 'Starts at' : 'Ends at',
      sub: start ? '${_f.name} freezes from here' : '${_f.name} thaws here',
      minute: start ? _f.startMinute : (_f.endMinute % 1440),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _f = _f.copyWith(startMinute: picked);
      } else {
        // 12:00 AM as an end means the end of the day, not its start.
        _f = _f.copyWith(endMinute: picked == 0 ? 1440 : picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final apps = ref.watch(freezeAppsProvider);
    final controller = ref.read(freezeControllerProvider.notifier);
    // Locked by the SAVED frost's Deep freeze, not this draft's: switching Deep
    // on for a running frost must not lock its own Save.
    final saved = ref.watch(freezeControllerProvider).frosts.where((f) => f.id == _f.id).firstOrNull;
    final locked = widget.isNew || saved == null ? null : controller.lockedUntil(saved);
    final session = _f.kind == FrostKind.session;
    final canSave = locked == null &&
        (_f.apps.count > 0 || _f.apps.keepOnly) &&
        (session || _f.days.isNotEmpty) &&
        // From == Until would be a 24-hour freeze nobody asked for.
        (session || _f.allDay || _f.startMinute % 1440 != _f.endMinute % 1440);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzSheetHead(
          title: _f.name,
          back: true,
          editable: locked == null,
          onTitle: locked != null
              ? null
              : () async {
                  final name = await nameFrost(context, initial: _f.name);
                  if (name != null && mounted) setState(() => _f = _f.copyWith(name: name));
                },
          right: FzHeadPill(
            label: 'Save',
            enabled: canSave,
            onTap: () {
              controller.saveFrost(_f);
              Navigator.of(context).pop();
            },
          ),
        ),
        if (locked != null) ...[
          FzWell(
            color: colors.accentSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                const Ic('never_open', size: 18, color: kFzIce),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Changes to this frost unlock at ${FreezeText.clock(locked)}',
                    style: AppText.sans(size: 13, color: colors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        IgnorePointer(
          ignoring: locked != null,
          child: Opacity(
            opacity: locked != null ? 0.5 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FzField(
                  label: _f.apps.keepOnly ? 'Keeps open' : 'Freezes',
                  onTap: () async {
                    final picked = await chooseApps(context, current: _f.apps, owner: _f.id);
                    if (picked != null && mounted) setState(() => _f = _f.copyWith(apps: picked));
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!apps.ios && _f.apps.packages.isNotEmpty)
                        FzStack(
                          apps: apps.of(_f.apps).take(3).toList(),
                          more: _f.apps.packages.length > 3 ? _f.apps.packages.length - 3 : 0,
                          edge: colors.bg,
                        )
                      else
                        Text(
                          _f.apps.isEmpty ? 'Choose' : FreezeApps.countLabel(_f.apps),
                          style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                        ),
                      Ic('chevron_right', size: 20, color: colors.textDim),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (session)
                  FzWell(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lasts', style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final m in _lengths)
                              FzChoice(
                                label: _lengthLabel(m),
                                on: _f.sessionMinutes == m,
                                onTap: () => setState(() {
                                  _f = m == null
                                      ? _f.copyWith(clearSessionMinutes: true, deep: false)
                                      : _f.copyWith(sessionMinutes: m);
                                }),
                              ),
                          ],
                        ),
                      ],
                    ),
                  )
                else ...[
                  FzWell(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Column(
                      children: [
                        FzTimeRow(
                          label: 'From',
                          first: true,
                          value: _f.allDay ? 'All day' : FreezeText.time(_f.startMinute),
                          onTap: () => unawaited(_pickTime(start: true)),
                        ),
                        FzTimeRow(
                          label: 'Until',
                          value: _f.allDay ? 'All day' : FreezeText.time(_f.endMinute),
                          onTap: () => unawaited(_pickTime(start: false)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FzDayPicker(
                    days: _f.days,
                    label: FreezeText.days(_f.days),
                    onChanged: (d) => setState(() => _f = _f.copyWith(days: d)),
                  ),
                  if (_f.fromDay != null || _f.untilDay != null) ...[
                    const SizedBox(height: 8),
                    FzField(
                      label: _dates(_f),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _f = _f.copyWith(clearDates: true)),
                        child: Text('Every week', style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.accent)),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                FzToggleRow(
                  title: 'Deep freeze',
                  sub: session && _f.sessionMinutes == null ? 'Needs an end time' : 'No thawing while it runs',
                  value: _f.deep,
                  onChanged: session && _f.sessionMinutes == null ? null : (v) => setState(() => _f = _f.copyWith(deep: v)),
                ),
                if (!widget.isNew) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      controller.deleteFrost(_f.id);
                      Navigator.of(context).pop();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Ic('delete', size: 18, color: kFzDanger),
                        const SizedBox(width: 6),
                        Text('Delete frost', style: AppText.sans(size: 15, weight: FontWeight.w800, color: kFzDanger)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _dates(Frost f) {
    String d(DateTime x) => '${FreezeText.day3[x.weekday - 1]} ${x.day}';
    if (f.fromDay != null && f.untilDay != null) return '${d(f.fromDay!)} – ${d(f.untilDay!)}';
    if (f.fromDay != null) return 'From ${d(f.fromDay!)}';
    return 'Until ${d(f.untilDay!)}';
  }
}

/// The time dialog (fz-edit-time): hour and minute wheels, AM/PM, "Set ·".
Future<int?> showFrostTimeDialog(BuildContext context, {required String title, required String sub, required int minute}) {
  return showDialog<int>(
    context: context,
    barrierColor: const Color(0x5C140F1C),
    builder: (_) => _TimeDialog(title: title, sub: sub, minute: minute),
  );
}

class _TimeDialog extends StatefulWidget {
  const _TimeDialog({required this.title, required this.sub, required this.minute});

  final String title;
  final String sub;
  final int minute;

  @override
  State<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends State<_TimeDialog> {
  static const _step = 5;
  late int _h12 = (widget.minute ~/ 60) % 12 == 0 ? 12 : (widget.minute ~/ 60) % 12;
  late int _m = ((widget.minute % 60) ~/ _step) * _step;
  late bool _pm = widget.minute ~/ 60 >= 12;
  late final _hours = FixedExtentScrollController(initialItem: _h12 - 1);
  late final _mins = FixedExtentScrollController(initialItem: _m ~/ _step);

  int get _value => ((_h12 % 12) + (_pm ? 12 : 0)) * 60 + _m;

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  Widget _wheel(FixedExtentScrollController c, int count, String Function(int) label, ValueChanged<int> onChanged) {
    final colors = context.colors;
    return SizedBox(
      width: 56,
      height: 108,
      child: ListWheelScrollView.useDelegate(
        controller: c,
        itemExtent: 36,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < count; i++)
              Center(child: Text(label(i), style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget ampm(String l, {required bool pm}) => GestureDetector(
          onTap: () => setState(() => _pm = pm),
          child: Container(
            height: 32,
            constraints: const BoxConstraints(minWidth: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _pm == pm ? colors.accent : colors.bg, borderRadius: BorderRadius.circular(16)),
            child: Text(l, style: AppText.sans(size: 15, color: _pm == pm ? Colors.white : colors.textMed)),
          ),
        );
    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
      child: SizedBox(
        width: 268,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.title, style: AppText.sans(size: 20, weight: FontWeight.w700, color: colors.text))),
                  Transform.translate(offset: const Offset(12, 0), child: const FzDismiss()),
                ],
              ),
              Text(widget.sub, style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(height: 36, decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(8))),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _wheel(_hours, 12, (i) => '${i + 1}', (i) => setState(() => _h12 = i % 12 + 1)),
                            Text(':', style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text)),
                            _wheel(_mins, 60 ~/ _step, (i) => (i * _step).toString().padLeft(2, '0'),
                                (i) => setState(() => _m = (i % (60 ~/ _step)) * _step)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(children: [ampm('AM', pm: false), const SizedBox(height: 6), ampm('PM', pm: true)]),
                ],
              ),
              const SizedBox(height: 16),
              FzBtn(label: 'Set · ${FreezeText.time(_value)}', onTap: () => Navigator.of(context).pop(_value)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- running, ending, deep --------------------------------------------------

/// A running frost (fz-active): what it froze, its rules, Thaw apps, End early.
Future<void> showActiveFrostSheet(BuildContext context, Frost frost, {required void Function(String target, String? label) onThaw}) =>
    showFzSheet<void>(context, builder: (_) => _ActiveFrost(frostId: frost.id, onThaw: onThaw));

class _ActiveFrost extends ConsumerWidget {
  const _ActiveFrost({required this.frostId, required this.onThaw});

  final String frostId;
  final void Function(String target, String? label) onThaw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final data = ref.watch(freezeControllerProvider);
    ref.watch(freezeClockProvider);
    final apps = ref.watch(freezeAppsProvider);
    final frost = data.frosts.where((f) => f.id == frostId).firstOrNull;
    if (frost == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final w = FreezeEngine.windowAt(frost, now);
    final session = frost.kind == FrostKind.session;
    final leftText = w?.end == null ? 'running' : '${FreezeText.left(w!.end!.difference(now))} left';
    final frozen = apps.ios ? const <({FzAppRef app, ThawGrant? grant})>[] : [
      for (final p in frost.apps.keepOnly ? const <String>[] : frost.apps.packages)
        if (!data.groups.alwaysOpen.contains(p))
          (app: apps.ref(p), grant: FreezeEngine.isFrozen(data, p, now) ? null : FreezeEngine.grantFor(data, p, now)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: kFzHeadButton,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(alignment: Alignment.centerLeft, child: Transform.translate(offset: const Offset(-12, 0), child: const FzDismiss())),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(23)),
                child: FzTrigger(session: session, live: true),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FzHeadPill(
                  label: 'Edit',
                  fill: FzFill.well,
                  onTap: () async {
                    final root = fzRootContext(context);
                    Navigator.of(context).pop();
                    await showFrostEditor(root, frost);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '${session ? 'Session' : 'Schedule'}, $leftText',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 15, color: colors.accent),
        ),
        const SizedBox(height: 2),
        Text(
          frost.name,
          textAlign: TextAlign.center,
          style: AppText.sans(size: 28, weight: FontWeight.w700, letterSpacing: -0.3, color: colors.text),
        ),
        const SizedBox(height: 20),
        FzWell(
          radius: 30,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(frost.apps.keepOnly ? 'Everything else is frozen' : 'Frozen',
                  style: AppText.sans(size: 17, color: colors.text)),
              const SizedBox(height: 12),
              if (frozen.isEmpty)
                FzCountTile(count: frost.apps.count)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in frozen) ...[
                        FzAppTile(
                          app: f.app,
                          state: f.grant == null ? FzTileState.frozen : FzTileState.thawed,
                          minutesLeft: f.grant == null ? null : (f.grant!.until.difference(now).inSeconds / 60).ceil(),
                          progress: f.grant == null ? 0 : _share(f.grant!, now),
                          onTap: f.grant == null ? () => onThaw(f.app.id, f.app.name) : null,
                        ),
                        const SizedBox(width: 18),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FzWell(
          radius: 30,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              if (!session) ...[
                _Fact('During this time', FreezeText.span(frost, short: false), first: true),
                _Fact('On these days', FreezeText.days(frost.days)),
              ] else
                _Fact('Lasts', frost.sessionMinutes == null ? 'Until you stop' : FreezeText.left(Duration(minutes: frost.sessionMinutes!)), first: true),
              _Fact('Deep freeze', frost.deep ? 'On' : 'Off'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FzBtn(
          label: 'Thaw apps',
          icon: 'thaw',
          onTap: () {
            Navigator.of(context).pop();
            onThaw(ThawGrant.allApps, null);
          },
        ),
        const SizedBox(height: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final hold = ref.read(freezeControllerProvider.notifier).lockedUntil(frost);
            if (hold != null) {
              final root = fzRootContext(context);
              Navigator.of(context).pop();
              await showDeepHoldSheet(root, name: frost.name, until: hold);
              return;
            }
            final end = await showEndFrostSheet(context, frost);
            if (end && context.mounted) Navigator.of(context).pop();
          },
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ic('pause', size: 19, color: colors.text),
                const SizedBox(width: 6),
                Text('End early', style: AppText.sans(size: 17, color: colors.text)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double _share(ThawGrant g, DateTime now) {
    final total = g.until.difference(g.startedAt).inSeconds;
    if (total <= 0) return 0;
    return (g.until.difference(now).inSeconds / total).clamp(0, 1).toDouble();
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.k, this.v, {this.first = false});

  final String k;
  final String v;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: colors.border))),
      child: Row(
        children: [
          Expanded(child: Text(k, style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text))),
          Text(v, style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed)),
        ],
      ),
    );
  }
}

/// End early (fz-end). True when the frost was ended.
Future<bool> showEndFrostSheet(BuildContext context, Frost frost) async {
  final ended = await showFzSheet<bool>(context, builder: (_) => _EndFrost(frost: frost));
  return ended ?? false;
}

class _EndFrost extends ConsumerWidget {
  const _EndFrost({required this.frost});

  final Frost frost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final session = frost.kind == FrostKind.session;
    final w = FreezeEngine.windowAt(frost, now);
    final next = w?.end == null ? null : FreezeEngine.nextStart(frost, w!.end!);
    final body = session
        ? 'Apps unfreeze now.'
        : 'Apps unfreeze now. ${next == null ? "It doesn't run again." : FreezeText.backAt(next, now)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzSheetTitle(session ? 'End ${frost.name} now?' : 'End ${frost.name} for today?'),
        FzSheetBody(body),
        FzBtn(
          label: session ? 'End it' : 'End for today',
          onTap: () {
            ref.read(freezeControllerProvider.notifier).endEarly(frost.id);
            Navigator.of(context).pop(true);
          },
        ),
        const SizedBox(height: 8),
        FzLink('Keep it running', weight: FontWeight.w700, onTap: () => Navigator.of(context).pop(false)),
      ],
    );
  }
}

/// Deep freeze holds (fz-deep): when it ends, what still works, and the one
/// useful action — going back to the work.
Future<void> showDeepHoldSheet(BuildContext context, {required String name, required DateTime until, VoidCallback? onBackToFocus}) =>
    showFzSheet<void>(context, builder: (_) => _DeepHold(name: name, until: until, onBackToFocus: onBackToFocus));

class _DeepHold extends ConsumerWidget {
  const _DeepHold({required this.name, required this.until, this.onBackToFocus});

  final String name;
  final DateTime until;
  final VoidCallback? onBackToFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final apps = ref.watch(freezeAppsProvider);
    final data = ref.watch(freezeControllerProvider);
    final now = DateTime.now();
    final floor = apps.ios
        ? const [FzAppRef('ios.phone', 'Phone'), FzAppRef('ios.messages', 'Messages'), FzAppRef('ios.maps', 'Maps'), FzAppRef('ios.wallet', 'Wallet')]
        : apps.of(data.groups.alwaysOpen);
    const glyphs = {'Phone': 'call', 'Messages': 'chat_bubble', 'Maps': 'map', 'Wallet': 'account_balance_wallet'};
    final when = name == 'Freeze now' ? 'No thawing until it ends.' : 'No thawing during $name.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: Transform.translate(offset: const Offset(12, -8), child: const FzDismiss())),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Ic('never_open', size: 28, color: kFzIce),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Deep freeze until ${FreezeText.clock(until)}',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text),
        ),
        const SizedBox(height: 6),
        Text(
          '$when Back in ${FreezeText.left(until.difference(now))}.',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
        ),
        const SizedBox(height: 18),
        FzWell(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Still open, always', style: AppText.sans(size: 13, weight: FontWeight.w800, color: colors.textMed)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final a in floor)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FzAppIcon(app: a, glyph: glyphs[a.name] ?? apps.glyphOf(a.id)),
                        const SizedBox(width: 7),
                        Text(a.name, style: AppText.sans(size: 15, color: colors.text)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FzBtn(
          label: 'Back to focus',
          onTap: () {
            Navigator.of(context).pop();
            onBackToFocus?.call();
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Changes to this frost unlock at ${FreezeText.clock(until)}',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim),
        ),
      ],
    );
  }
}
