import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../services/haptics/haptics_service.dart';
import '../widgets/plan_sheet.dart';

/// Duration presets shown in the picker grid, paired with the minute value
/// each cell commits when tapped (`plan-pick-duration`).
const _presets = <_Preset>[
  _Preset('15 min', 15),
  _Preset('25 min', 25),
  _Preset('30 min', 30),
  _Preset('45 min', 45),
  _Preset('1 hr', 60),
  _Preset('1.5 hr', 90),
];

/// Presents the `plan-pick-duration` floating sheet. [current] is the currently
/// selected duration so its preset renders active. Tapping a preset cell returns
/// its minute value; "Custom duration → Set" opens [_showCustomDuration] and
/// returns the fine-tuned value from there. Returns `null` if dismissed.
Future<int?> showDurationPicker(BuildContext context, {int current = 30}) {
  return showPlanSheet<int>(
    context,
    builder: (_) => _DurationSheet(current: current),
  );
}

class _Preset {
  const _Preset(this.label, this.minutes);
  final String label;
  final int minutes;
}

class _DurationSheet extends StatelessWidget {
  const _DurationSheet({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final isCustom = !_presets.any((p) => p.minutes == current);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlanSheetTitle('Duration', sub: 'How long do you expect this to take?'),
        for (var row = 0; row < _presets.length; row += 3) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var i = row; i < row + 3 && i < _presets.length; i++) ...[
                if (i > row) const SizedBox(width: 8),
                Expanded(
                  child: _PresetCell(
                    preset: _presets[i],
                    active: _presets[i].minutes == current,
                    onTap: () => Navigator.of(context).pop(_presets[i].minutes),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 10),
        PlanOptRow(
          icon: 'tune',
          label: 'Custom duration',
          active: isCustom,
          trailing: PlanSetPill(label: isCustom ? '$current min' : null),
          onTap: () async {
            final picked = await _showCustomDuration(context, initial: current);
            if (picked != null && context.mounted) {
              Navigator.of(context).pop(picked);
            }
          },
        ),
      ],
    );
  }
}

/// A single preset cell in the 3-column grid: 17 on a well, accent / white 800
/// when it is the current duration.
class _PresetCell extends StatelessWidget {
  const _PresetCell({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  final _Preset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? colors.accent : colors.bg,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                preset.label,
                maxLines: 1,
                softWrap: false,
                style: AppText.sans(
                  size: 17,
                  weight: active ? FontWeight.w800 : FontWeight.w700,
                  color: active ? Colors.white : colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Presents the `plan-pick-duration-custom` centered dialog. The stepper, slider
/// and quick chips mutate local state; "Set · N min" returns the chosen minutes.
Future<int?> _showCustomDuration(BuildContext context, {required int initial}) {
  return showPlanDialog<int>(context, child: _CustomDurationDialog(initial: initial));
}

class _CustomDurationDialog extends ConsumerStatefulWidget {
  const _CustomDurationDialog({required this.initial});

  /// The duration the task has now; a preset value opens on the old 50.
  final int initial;

  @override
  ConsumerState<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends ConsumerState<_CustomDurationDialog> {
  static const _min = 5;
  static const _max = 120;
  static const _chips = [
    _Preset('45 min', 45),
    _Preset('1 hr', 60),
    _Preset('1.5 hr', 90),
    _Preset('2 hr', 120),
  ];

  late int _minutes = _presets.any((p) => p.minutes == widget.initial) ? 50 : widget.initial.clamp(_min, _max);

  /// [detent] is true only for the slider — see the note in
  /// `focus_duration_dialog.dart`; Pickers get one event (§7) and this is it.
  void _setMinutes(int value, {bool detent = false}) {
    final next = value.clamp(_min, _max);
    if (detent && next != _minutes) ref.read(hapticsProvider).sliderStop();
    setState(() => _minutes = next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = (_minutes - _min) / (_max - _min);
    return PlanCenterDialog(
      title: 'Custom duration',
      sub: 'Fine-tune the time you need',
      ctaLabel: 'Set · $_minutes min',
      onCta: () => Navigator.of(context).pop(_minutes),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlanStepButton(
                icon: 'remove',
                label: 'Five minutes less',
                onTap: () => _setMinutes(_minutes - 5),
              ),
              const SizedBox(width: 18),
              // Scales down for three digits, which do not fit the 252 card.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textBaseline: TextBaseline.alphabetic,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    children: [
                      Text(
                        '$_minutes',
                        style: AppText.sans(size: 50, weight: FontWeight.w800, height: 1, color: colors.text),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'min',
                        style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.textMed),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              PlanStepButton(
                icon: 'add',
                label: 'Five minutes more',
                onTap: () => _setMinutes(_minutes + 5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DurationSlider(
            fraction: fraction,
            onChanged: (value) => _setMinutes(
              (_min + value * (_max - _min)).round(),
              detent: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: PlanQuickChip(
                    label: _chips[i].label,
                    size: 15,
                    expand: true,
                    active: _minutes == _chips[i].minutes,
                    onTap: () => _setMinutes(_chips[i].minutes),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The custom-duration slider: a `bg` track with an accent fill and a white
/// accent-bordered thumb. Drags translate the local fraction to minutes.
class _DurationSlider extends StatelessWidget {
  const _DurationSlider({required this.fraction, required this.onChanged});

  final double fraction;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void handle(Offset local) => onChanged((local.dx / width).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => handle(details.localPosition),
          onHorizontalDragUpdate: (details) => handle(details.localPosition),
          child: SizedBox(
            height: 18,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(fraction * 2 - 1, 0),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.accent, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
