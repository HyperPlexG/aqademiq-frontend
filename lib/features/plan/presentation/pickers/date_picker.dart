import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/calendar_grid.dart';

/// plan-pick-date — bottom sheet date picker (spec section-02b).
///
/// Presents an interactive "Pick a date" sheet over the dimmed real screen and
/// resolves to the chosen [DateTime] (date-only), or `null` if dismissed.
Future<DateTime?> showTaskDatePicker(
  BuildContext context, {
  DateTime? initial,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x4C140F1C),
    builder: (_) => _DatePickerSheet(initial: initial ?? DateTime.now()),
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

String _chipLabel(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]}';

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

  void _select(DateTime d) => setState(() => _selected = _dateOnly(d));

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = _dateOnly(DateTime.now());
    final firstCol = DateTime(_month.year, _month.month).weekday - 1;
    final total = DateTime(_month.year, _month.month + 1, 0).day;
    final accentDay =
        (_selected.year == _month.year && _selected.month == _month.month)
            ? _selected.day
            : null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
        boxShadow: colors.sheetShadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0DDD7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pick a date',
                      style: AppText.sans(
                        size: 20,
                        weight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                  ),
                  _CloseButton(onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 12),
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
                onDayTap: (day) =>
                    _select(DateTime(_month.year, _month.month, day)),
              ),
              const SizedBox(height: 14),
              _SetDateButton(
                label: _selected == today
                    ? 'Set date · Today'
                    : 'Set date · ${_chipLabel(_selected)}',
                onTap: () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChipsRow extends StatelessWidget {
  const _QuickChipsRow({required this.selected, required this.onPick});

  final DateTime selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));
    return Row(
      children: [
        _QuickChip(
          label: 'Today',
          active: selected == today,
          onTap: () => onPick(today),
        ),
        const SizedBox(width: 6),
        _QuickChip(
          label: 'Tomorrow',
          active: selected == tomorrow,
          onTap: () => onPick(tomorrow),
        ),
        const SizedBox(width: 6),
        _QuickChip(
          label: 'Next week',
          active: selected == nextWeek,
          onTap: () => onPick(nextWeek),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.accent : colors.bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: AppText.sans(
            size: 10.5,
            weight: FontWeight.w700,
            color: active ? Colors.white : colors.textMed,
          ),
        ),
      ),
    );
  }
}

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: onPrev,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.chevron_left, size: 20, color: colors.text),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onNext,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.chevron_right, size: 20, color: colors.text),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SetDateButton extends StatelessWidget {
  const _SetDateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: colors.ink,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.sans(size: 13, weight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
        child: Text('✕', style: TextStyle(fontSize: 12, color: colors.textMed, height: 1)),
      ),
    );
  }
}
