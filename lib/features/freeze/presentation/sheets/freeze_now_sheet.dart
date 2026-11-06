import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/repositories/focus_repository.dart';
import '../../../../shared/widgets/ic.dart';
import '../../domain/freeze_engine.dart';
import '../../domain/freeze_models.dart';
import '../../providers/freeze_controller.dart';
import '../freeze_apps.dart';
import '../widgets/fz_widgets.dart';
import 'choose_apps_sheet.dart';

/// Freeze now (fz-session): what freezes, for how long, and whether Deep
/// freeze closes the way out. "This session" follows the running focus
/// session and thaws when it ends.
Future<void> showFreezeNowSheet(BuildContext context) =>
    showFzSheet<void>(context, builder: (_) => const _FreezeNow());

enum _Length { session, hour, twoHours, untilStop }

class _FreezeNow extends ConsumerStatefulWidget {
  const _FreezeNow();

  @override
  ConsumerState<_FreezeNow> createState() => _FreezeNowState();
}

class _FreezeNowState extends ConsumerState<_FreezeNow> {
  late AppSet _apps;
  _Length? _length;
  bool _deep = false;

  @override
  void initState() {
    super.initState();
    final data = ref.read(freezeControllerProvider);
    _apps = data.recentApps.isEmpty ? (data.frosts.isEmpty ? AppSet.empty : data.frosts.first.apps) : data.recentApps;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final apps = ref.watch(freezeAppsProvider);
    final focus = ref.watch(focusControllerProvider);
    final focusRunning = focus.status == FocusStatus.running && focus.endsAt != null;
    // "This session" picked, then the session ended with the sheet open: fall
    // back rather than freeze with a stale or missing end.
    final picked = _length == _Length.session && !focusRunning ? null : _length;
    final length = picked ?? (focusRunning ? _Length.session : _Length.hour);
    final now = DateTime.now();
    final sessionMins = focusRunning ? (focus.endsAt!.difference(now).inSeconds / 60).ceil() : 0;
    final endsAt = switch (length) {
      _Length.session => focus.endsAt,
      _Length.hour => now.add(const Duration(hours: 1)),
      _Length.twoHours => now.add(const Duration(hours: 2)),
      _Length.untilStop => null,
    };
    final deepAllowed = endsAt != null;
    final note = endsAt == null
        ? 'Runs until you stop it'
        : length == _Length.session
            ? 'Thaws when your focus session ends · ${FreezeText.clock(endsAt)}'
            : 'Thaws by itself at ${FreezeText.clock(endsAt)}';
    final count = _apps.count;
    final label = _apps.keepOnly
        ? 'Freeze everything else'
        : (count == 0 ? 'Choose apps first' : 'Freeze ${FreezeApps.countLabel(_apps)}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FzSheetHead(title: 'Freeze now'),
        FzField(
          label: _apps.keepOnly ? 'Keeps open' : 'Freezes',
          onTap: () async {
            final picked = await chooseApps(context, current: _apps, owner: 'now');
            if (picked != null && mounted) setState(() => _apps = picked);
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!apps.ios && _apps.packages.isNotEmpty)
                FzStack(apps: apps.of(_apps).take(3).toList(), more: _apps.packages.length - 3 > 0 ? _apps.packages.length - 3 : 0, edge: colors.bg)
              else
                Text(count == 0 ? 'None' : FreezeApps.countLabel(_apps),
                    style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
              Ic('chevron_right', size: 20, color: colors.textDim),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
          child: Text('For how long', style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (focusRunning)
              FzChoice(
                label: 'This session · $sessionMins min',
                on: length == _Length.session,
                onTap: () => setState(() => _length = _Length.session),
              ),
            FzChoice(label: '1 hr', on: length == _Length.hour, onTap: () => setState(() => _length = _Length.hour)),
            FzChoice(label: '2 hr', on: length == _Length.twoHours, onTap: () => setState(() => _length = _Length.twoHours)),
            FzChoice(
              label: 'Until I stop',
              on: length == _Length.untilStop,
              onTap: () => setState(() {
                _length = _Length.untilStop;
                _deep = false;
              }),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FzToggleRow(
          title: 'Deep freeze',
          sub: deepAllowed ? 'No thawing until it ends' : 'Needs an end time',
          value: _deep && deepAllowed,
          onChanged: deepAllowed ? (v) => setState(() => _deep = v) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
          child: Text(note, textAlign: TextAlign.center, style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
        ),
        FzBtn(
          label: label,
          enabled: count > 0 || _apps.keepOnly,
          onTap: () {
            ref.read(freezeControllerProvider.notifier).freezeNow(
                  apps: _apps,
                  endsAt: endsAt,
                  deep: _deep && deepAllowed,
                  withFocus: length == _Length.session,
                );
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 8),
        FzLink(
          'Save as a frost',
          color: colors.accent,
          weight: FontWeight.w800,
          onTap: count == 0 && !_apps.keepOnly
              ? null
              : () async {
                  final name = await nameFrost(context, initial: 'My frost');
                  if (name == null || !mounted) return;
                  final minutes = switch (length) {
                    _Length.session => focusRunning ? focus.durationMin : 60,
                    _Length.hour => 60,
                    _Length.twoHours => 120,
                    _Length.untilStop => null,
                  };
                  ref.read(freezeControllerProvider.notifier).saveAsFrost(
                        name: name,
                        apps: _apps,
                        minutes: minutes,
                        deep: _deep && deepAllowed,
                      );
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

/// Name this frost (fz-name): "Shown on the frozen screen."
Future<String?> nameFrost(BuildContext context, {required String initial}) =>
    showFzSheet<String>(context, builder: (_) => _NameFrost(initial: initial));

class _NameFrost extends StatefulWidget {
  const _NameFrost({required this.initial});

  final String initial;

  @override
  State<_NameFrost> createState() => _NameFrostState();
}

class _NameFrostState extends State<_NameFrost> {
  late final TextEditingController _text = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final name = _text.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name.length > 40 ? name.substring(0, 40) : name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FzSheetHead(
          title: 'Name this frost',
          back: true,
          right: ListenableBuilder(
            listenable: _text,
            builder: (_, _) => FzHeadPill(label: 'Save', enabled: _text.text.trim().isNotEmpty, onTap: _save),
          ),
        ),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(26)),
          child: TextField(
            controller: _text,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            cursorColor: colors.accent,
            style: AppText.sans(size: 15, color: colors.text),
            decoration: const InputDecoration.collapsed(hintText: 'Frost name').copyWith(counterText: ''),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
          child: Text('Shown on the frozen screen.', style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
        ),
      ],
    );
  }
}
