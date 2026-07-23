import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/calendar_grid.dart';

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// One month the calendar popup renders, computed for any year/month (0=Mon
/// column for day 1, real day count), with the selected day accented when the
/// view is on the selected month.
class _MonthView {
  _MonthView(this.year, this.month, {this.accentDay})
      : firstCol = DateTime(year, month).weekday - 1, // Mon=0 … Sun=6
        total = DateTime(year, month + 1, 0).day;

  final int year;
  final int month;
  final int firstCol;
  final int total;
  final int? accentDay;

  String get label => '${_monthNames[month - 1]} $year';
}

/// Presents the month picker popup (`plan-month` / `plan-monthyear`): a card that
/// drops from beneath the dimmed planner header. Opens on [selected]'s month with
/// that day accented. Tapping a day returns that [DateTime]; the title chevron
/// flips to a month/year wheel that also returns a [DateTime]. Returns `null` on
/// dismiss.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  DateTime? selected,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: const Color(0x47140F1C),
    builder: (_) => _MonthPickerPopup(selected: selected),
  );
}

class _MonthPickerPopup extends StatelessWidget {
  const _MonthPickerPopup({this.selected});

  final DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + 92;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topInset, left: 12, right: 12),
        child: _MonthCard(selected: selected),
      ),
    );
  }
}

class _MonthCard extends StatefulWidget {
  const _MonthCard({this.selected});

  final DateTime? selected;

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  bool _wheelOpen = false;
  late final DateTime _selected = widget.selected ?? DateTime.now();
  late int _year = _selected.year;
  late int _month = _selected.month;

  _MonthView get _view => _MonthView(
        _year,
        _month,
        // Accent the selected day only while viewing its month.
        accentDay: (_year == _selected.year && _month == _selected.month)
            ? _selected.day
            : null,
      );

  void _prevMonth() => setState(() {
        if (_month == 1) {
          _month = 12;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextMonth() => setState(() {
        if (_month == 12) {
          _month = 1;
          _year++;
        } else {
          _month++;
        }
      });

  void _pickDay(int day) =>
      Navigator.of(context).pop(DateTime(_year, _month, day));

  void _applyWheel(int month, int year) => setState(() {
        _month = month;
        _year = year;
        _wheelOpen = false;
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x29000000),
              blurRadius: 44,
              offset: Offset(0, 14),
            ),
          ],
        ),
        padding: _wheelOpen
            ? const EdgeInsets.fromLTRB(15, 15, 15, 22)
            : const EdgeInsets.fromLTRB(15, 15, 15, 18),
        child: _wheelOpen
            ? _WheelBody(
                view: _view,
                onClose: () => setState(() => _wheelOpen = false),
                onPick: _applyWheel,
              )
            : _CalendarBody(
                view: _view,
                onOpenWheel: () => setState(() => _wheelOpen = true),
                onPrev: _prevMonth,
                onNext: _nextMonth,
                onDayTap: _pickDay,
              ),
      ),
    );
  }
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.view,
    required this.onOpenWheel,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  final _MonthView view;
  final VoidCallback onOpenWheel;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenWheel,
              child: Row(
                children: [
                  Text(
                    view.label,
                    style: AppText.sans(
                      size: 17,
                      weight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.chevron_right, size: 16, color: colors.accent),
                ],
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPrev,
                  child: Icon(Icons.chevron_left, size: 20, color: colors.text),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onNext,
                  child: Icon(Icons.chevron_right, size: 20, color: colors.text),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        CalendarGrid(
          firstCol: view.firstCol,
          total: view.total,
          accentDay: view.accentDay,
          onDayTap: onDayTap,
        ),
      ],
    );
  }
}

/// Month + year wheels — scroll to a month/year and tap "Done" (the highlighted
/// centre) to apply. Both wheels drive the calendar behind them.
class _WheelBody extends StatefulWidget {
  const _WheelBody({
    required this.view,
    required this.onClose,
    required this.onPick,
  });

  final _MonthView view;
  final VoidCallback onClose;
  final void Function(int month, int year) onPick;

  @override
  State<_WheelBody> createState() => _WheelBodyState();
}

class _WheelBodyState extends State<_WheelBody> {
  late int _month = widget.view.month;
  late int _year = widget.view.year;
  // A generous, fixed range centred on the current decade.
  late final List<int> _years = [
    for (var y = widget.view.year - 6; y <= widget.view.year + 6; y++) y,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onClose,
          child: Row(
            children: [
              Text(
                '${_monthNames[_month - 1]} $_year',
                style: AppText.sans(
                  size: 17,
                  weight: FontWeight.w800,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.expand_less, size: 16, color: colors.accent),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -4,
              right: -4,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(
              height: 168,
              child: Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      count: 12,
                      initialIndex: _month - 1,
                      label: (i) => _monthNames[i],
                      onChanged: (i) => setState(() => _month = i + 1),
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      count: _years.length,
                      initialIndex: _years.indexOf(_year),
                      label: (i) => '${_years[i]}',
                      onChanged: (i) => setState(() => _year = _years[i]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onPick(_month, _year),
          child: Center(
            child: Text(
              'Done',
              style: AppText.sans(
                size: 13,
                weight: FontWeight.w800,
                color: colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A scrollable wheel column: centred value large, neighbours dimmed.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.initialIndex,
    required this.label,
    required this.onChanged,
  });

  final int count;
  final int initialIndex;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialIndex.clamp(0, widget.count - 1));
  late int _selected = widget.initialIndex.clamp(0, widget.count - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: 42,
      perspective: 0.004,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        setState(() => _selected = i);
        widget.onChanged(i);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (context, i) {
          final selected = i == _selected;
          return Center(
            child: Text(
              widget.label(i),
              style: AppText.sans(
                size: selected ? 22 : 18,
                weight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? colors.text : const Color(0xFFC8C4BE),
              ),
            ),
          );
        },
      ),
    );
  }
}
