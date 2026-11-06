import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/calendar_grid.dart';
import '../../../../shared/widgets/ic.dart';
import '../widgets/plan_sheet.dart';

/// plan-pick-date — the v11 floating "Pick a date" sheet (spec section-02b).
///
/// Presents an interactive date sheet over the dimmed real screen and resolves
/// to the chosen [DateTime] (date-only), or `null` if dismissed.
Future<DateTime?> showTaskDatePicker(
  BuildContext context, {
  DateTime? initial,
}) {
  return showPlanSheet<DateTime>(
    context,
    builder: (_) => _DatePickerSheet(initial: initial ?? AppDate.today()),
  );
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdaysShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _chipLabel(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';

/// The label shown back on the add-task row for a chosen date.
String taskDateLabel(DateTime d) =>
    '${_weekdaysShort[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]}';

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initial});

  final DateTime initial;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected = _dateOnly(widget.initial);
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  void _select(DateTime d) => setState(() {
        _selected = _dateOnly(d);
        // A quick chip can land in another month; follow it there.
        _month = DateTime(_selected.year, _selected.month);
      });

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    // The planner's today: the fixture date in mock mode, so "Today" here is
    // the day the Plan screen calls today.
    final today = AppDate.today();
    final firstCol = DateTime(_month.year, _month.month).weekday - 1;
    final total = DateTime(_month.year, _month.month + 1, 0).day;
    final accentDay =
        (_selected.year == _month.year && _selected.month == _month.month) ? _selected.day : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlanSheetTitle('Pick a date'),
        _QuickChipsRow(selected: _selected, onPick: _select),
        const SizedBox(height: 14),
        _MonthHeader(
          label: '${_months[_month.month - 1]} ${_month.year}',
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
        ),
        const SizedBox(height: 10),
        CalendarGrid(
          firstCol: firstCol,
          total: total,
          accentDay: accentDay,
          onDayTap: (day) => _select(DateTime(_month.year, _month.month, day)),
        ),
        const SizedBox(height: 14),
        PlanCta(
          label: _selected == today ? 'Set date · Today' : 'Set date · ${taskDateLabel(_selected)}',
          onTap: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

/// Today / Tomorrow / the chosen day / Next week. The chosen day gets its own
/// chip (v11 "18 May") when it is none of the other three.
class _QuickChipsRow extends StatelessWidget {
  const _QuickChipsRow({required this.selected, required this.onPick});

  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final today = AppDate.today();
    // Calendar days, not 24-hour steps: across a DST change those land an hour
    // off midnight and never equal the (date-only) selection.
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final nextWeek = DateTime(today.year, today.month, today.day + 7);
    final other = selected != today && selected != tomorrow && selected != nextWeek;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PlanQuickChip(label: 'Today', active: selected == today, onTap: () => onPick(today)),
          const SizedBox(width: 6),
          PlanQuickChip(label: 'Tomorrow', active: selected == tomorrow, onTap: () => onPick(tomorrow)),
          if (other) ...[
            const SizedBox(width: 6),
            PlanQuickChip(label: _chipLabel(selected), active: true, onTap: () => onPick(selected)),
          ],
          const SizedBox(width: 6),
          PlanQuickChip(label: 'Next week', active: selected == nextWeek, onTap: () => onPick(nextWeek)),
        ],
      ),
    );
  }
}

/// "May 2026" 17/800 with ‹ › to step the month.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
          ),
        ),
        _MonthArrow(icon: 'back', label: 'Previous month', color: colors.textDim, onTap: onPrev),
        const SizedBox(width: 6),
        _MonthArrow(icon: 'chevron_right', label: 'Next month', color: colors.text, onTap: onNext),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.label, required this.color, required this.onTap});

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(child: Ic(icon, size: 18, color: color)),
        ),
      ),
    );
  }
}
