import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/task.dart';
import '../../../../shared/widgets/ic.dart';
import '../widgets/plan_sheet.dart';

/// Presents the Repeat picker sheet (`plan-pick-repeat`) and returns the chosen
/// [RepeatRule] (recurrence the planner actually expands), or `null` if
/// dismissed. A `frequency: none` rule means "No repeat".
///
/// [current] marks the rule the task has now (none → "No repeat"); [date], the
/// day the task is on, words the Weekly / Monthly rows ("Every Monday",
/// "On the 18th"). Neither changes what a row returns.
Future<RepeatRule?> showRepeatPicker(
  BuildContext context, {
  RepeatRule? current,
  DateTime? date,
}) {
  return showPlanSheet<RepeatRule>(
    context,
    builder: (_) => _RepeatSheet(current: current, date: date),
  );
}

/// Human label for a [RepeatRule], shown on the Add-task "Repeat" row.
String repeatRuleLabel(RepeatRule? rule) {
  if (rule == null || rule.frequency == RepeatFrequency.none) return 'No repeat';
  switch (rule.frequency) {
    case RepeatFrequency.daily:
      return rule.interval == 1 ? 'Every day' : 'Every ${rule.interval} days';
    case RepeatFrequency.weekly:
      final wd = rule.weekdays.toSet();
      if (wd.length == 5 && wd.containsAll({1, 2, 3, 4, 5})) return 'Weekdays';
      if (rule.interval != 1) return 'Every ${rule.interval} weeks';
      // Plain "Weekly" carries no days — it repeats on the task's own weekday.
      // A hand-picked set (Mon & Wed) is a custom rule; calling it "Weekly"
      // ticked the wrong row in the picker.
      return wd.isEmpty ? 'Weekly' : 'Custom';
    case RepeatFrequency.monthly:
      return rule.interval == 1 ? 'Monthly' : 'Every ${rule.interval} months';
    case RepeatFrequency.none:
    case RepeatFrequency.custom:
      return 'Custom';
  }
}

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// The sheet body (v11 `PICK_REPEAT`).
class _RepeatSheet extends StatelessWidget {
  const _RepeatSheet({this.current, this.date});

  final RepeatRule? current;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final label = repeatRuleLabel(current);
    const standard = {'No repeat', 'Every day', 'Weekdays', 'Weekly', 'Monthly'};
    final isCustom = !standard.contains(label);
    final d = date;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlanSheetTitle('Repeat', sub: 'Make this a recurring task'),
        PlanOptRow(
          icon: 'block',
          label: 'No repeat',
          active: label == 'No repeat',
          onTap: () => Navigator.of(context).pop(const RepeatRule(frequency: RepeatFrequency.none)),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'today',
          label: 'Every day',
          active: label == 'Every day',
          onTap: () => Navigator.of(context).pop(const RepeatRule(frequency: RepeatFrequency.daily)),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'work_outline',
          label: 'Weekdays',
          sub: 'Mon – Fri',
          active: label == 'Weekdays',
          onTap: () => Navigator.of(context).pop(
            const RepeatRule(frequency: RepeatFrequency.weekly, weekdays: [1, 2, 3, 4, 5]),
          ),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'event_repeat',
          label: 'Weekly',
          sub: d != null ? 'Every ${_weekdayNames[d.weekday - 1]}' : 'Same weekday',
          active: label == 'Weekly',
          onTap: () => Navigator.of(context).pop(const RepeatRule(frequency: RepeatFrequency.weekly)),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'calendar_month',
          label: 'Monthly',
          sub: d != null ? 'On the ${_ordinal(d.day)}' : 'Same date',
          active: label == 'Monthly',
          onTap: () => Navigator.of(context).pop(const RepeatRule(frequency: RepeatFrequency.monthly)),
        ),
        const SizedBox(height: 1),
        PlanOptRow(
          icon: 'tune',
          label: 'Custom…',
          active: isCustom,
          trailing: PlanSetPill(label: isCustom ? label : null),
          onTap: () async {
            final result = await _showCustomRepeatDialog(context);
            if (result != null && context.mounted) {
              Navigator.of(context).pop(result);
            }
          },
        ),
      ],
    );
  }
}

/// Opens the centered Custom repeat dialog (`plan-pick-repeat-custom`, w=344)
/// and returns the built [RepeatRule], or `null` if dismissed.
Future<RepeatRule?> _showCustomRepeatDialog(BuildContext context) {
  return showPlanDialog<RepeatRule>(context, child: const _CustomRepeatDialog());
}

/// The centered Custom repeat dialog (v11 `PICK_REPEAT_CUSTOM`).
class _CustomRepeatDialog extends StatefulWidget {
  const _CustomRepeatDialog();

  @override
  State<_CustomRepeatDialog> createState() => _CustomRepeatDialogState();
}

class _CustomRepeatDialogState extends State<_CustomRepeatDialog> {
  static const _units = ['Days', 'Weeks', 'Months'];
  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  int _interval = 2;
  int _unitIndex = 1; // Weeks
  final Set<int> _activeDays = {0, 2}; // Mon & Wed

  String get _ctaLabel {
    final unit = _units[_unitIndex].toLowerCase();
    final singular = _interval == 1 ? unit.substring(0, unit.length - 1) : unit;
    return 'Every $_interval $singular';
  }

  /// Build the recurrence from the dialog's interval / unit / weekday picks.
  /// Days→daily, Weeks→weekly (with chosen weekdays, 1=Mon…7=Sun), Months→monthly.
  RepeatRule get _rule => switch (_unitIndex) {
        0 => RepeatRule(frequency: RepeatFrequency.daily, interval: _interval),
        2 => RepeatRule(frequency: RepeatFrequency.monthly, interval: _interval),
        _ => RepeatRule(
            frequency: RepeatFrequency.weekly,
            interval: _interval,
            weekdays: (_activeDays.map((i) => i + 1).toList()..sort()),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PlanCenterDialog(
      title: 'Custom repeat',
      sub: 'Set your own recurring rhythm',
      width: 344,
      ctaLabel: 'Save · $_ctaLabel',
      onCta: () => Navigator.of(context).pop(_rule),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IntervalRow(
            value: _interval,
            onDecrement: _interval > 1 ? () => setState(() => _interval--) : null,
            onIncrement: () => setState(() => _interval++),
          ),
          const SizedBox(height: 14),
          _UnitSegmented(
            units: _units,
            selected: _unitIndex,
            onSelect: (i) => setState(() => _unitIndex = i),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'ON THESE DAYS',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: AppText.em(0.08, 12),
                color: colors.textDim,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            // 40 circles, smaller only when a narrow phone squeezes the card.
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Explicit <double>: with bare int literals these infer `num`.
                final side = math.min<double>(40, math.max<double>(28, (constraints.maxWidth - 6 * 4) / 7));
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < _dayLetters.length; i++)
                      _DayCircle(
                        letter: _dayLetters[i],
                        side: side,
                        active: _activeDays.contains(i),
                        onTap: () => setState(() {
                          if (!_activeDays.add(i)) _activeDays.remove(i);
                        }),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// "Repeat every" with a − / count / + stepper.
class _IntervalRow extends StatelessWidget {
  const _IntervalRow({
    required this.value,
    required this.onIncrement,
    this.onDecrement,
  });

  final int value;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Repeat every',
            style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
          ),
        ),
        Semantics(
          button: true,
          label: 'Less often',
          excludeSemantics: true,
          onTap: onDecrement,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDecrement,
            child: Opacity(
              opacity: onDecrement == null ? 0.4 : 1,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.textMed, width: 2),
                ),
                child: Ic('remove', size: 16, color: colors.textMed),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 14),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'More often',
          excludeSemantics: true,
          onTap: onIncrement,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onIncrement,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(2),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accent),
              child: const Ic('add', size: 17, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Days / Weeks / Months — 36 high, radius 10, accent when chosen.
class _UnitSegmented extends StatelessWidget {
  const _UnitSegmented({
    required this.units,
    required this.selected,
    required this.onSelect,
  });

  final List<String> units;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < units.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? colors.accent : colors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    units[i],
                    style: AppText.sans(
                      size: 15,
                      weight: i == selected ? FontWeight.w800 : FontWeight.w700,
                      color: i == selected ? Colors.white : colors.textMed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A 40 weekday toggle circle.
class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.letter,
    required this.side,
    required this.active,
    required this.onTap,
  });

  final String letter;
  final double side;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: side,
          height: side,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? colors.accent : colors.bg,
          ),
          child: Text(
            letter,
            style: AppText.sans(
              size: 15,
              weight: FontWeight.w800,
              color: active ? Colors.white : colors.textMed,
            ),
          ),
        ),
      ),
    );
  }
}
