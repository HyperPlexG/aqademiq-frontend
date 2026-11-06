import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../services/haptics/haptics_service.dart';
import '../../../../shared/widgets/calendar_grid.dart';
import '../../../../shared/widgets/ic.dart';

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
            BoxShadow(color: Color(0x29000000), blurRadius: 44, offset: Offset(0, 14)),
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
            Semantics(
              button: true,
              label: 'Choose month and year',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenWheel,
                child: Row(
                  children: [
                    Text(
                      view.label,
                      style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text),
                    ),
                    const SizedBox(width: 4),
                    Ic('chevron_right', size: 20, color: colors.accent),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _NavArrow(icon: 'back', label: 'Previous month', onTap: onPrev),
                const SizedBox(width: 4),
                _NavArrow(icon: 'chevron_right', label: 'Next month', onTap: onNext),
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
                style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.accent),
              ),
              const SizedBox(width: 4),
              Ic('chevron_down', size: 20, color: colors.accent),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.center,
          // The highlight hangs 4 past each side; the default hardEdge clip
          // cut it off flush.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -4,
              right: -4,
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: colors.hilite,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(
              height: 210,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _Wheel(
                        count: 12,
                        initialIndex: _month - 1,
                        label: (i) => _monthNames[i],
                        alignment: Alignment.centerLeft,
                        onChanged: (i) => setState(() => _month = i + 1),
                      ),
                    ),
                    Expanded(
                      child: _Wheel(
                        count: _years.length,
                        initialIndex: _years.indexOf(_year),
                        label: (i) => '${_years[i]}',
                        alignment: Alignment.centerRight,
                        onChanged: (i) => setState(() => _year = _years[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onPick(_month, _year),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Done',
                      style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A scrollable wheel column: centred value large, neighbours dimmed.
///
/// Consumer-backed for the detent tick only — see spec Finding 03; a
/// `ListWheelScrollView` does not self-haptic the way a `CupertinoPicker` does.
class _Wheel extends ConsumerStatefulWidget {
  const _Wheel({
    required this.count,
    required this.initialIndex,
    required this.label,
    required this.onChanged,
    this.alignment = Alignment.center,
  });

  final int count;
  final int initialIndex;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  /// Months sit on the left of the card, years on the right.
  final Alignment alignment;

  @override
  ConsumerState<_Wheel> createState() => _WheelState();
}

class _WheelState extends ConsumerState<_Wheel> {
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
      perspective: 0.002,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        ref.read(hapticsProvider).wheelItem();
        setState(() => _selected = i);
        widget.onChanged(i);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.count,
        builder: (context, i) {
          final distance = (i - _selected).abs();
          final selected = distance == 0;
          // v11: the centre row 28/800, then the text colour at 50% and 28%.
          final opacity = selected ? 1.0 : (distance == 1 ? 0.5 : 0.28);
          return Align(
            alignment: widget.alignment,
            child: Text(
              widget.label(i),
              maxLines: 1,
              softWrap: false,
              style: AppText.sans(
                size: selected ? 28 : 22,
                weight: selected ? FontWeight.w800 : FontWeight.w600,
                color: colors.text.withValues(alpha: opacity),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A ‹ or › that steps the calendar a month (20, with a 36 target).
class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Ic(icon, size: 20, color: context.colors.text)),
        ),
      ),
    );
  }
}
