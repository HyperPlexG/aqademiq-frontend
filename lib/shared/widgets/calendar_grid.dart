import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// A month calendar grid (v11 `CalGrid`): MON–SUN headers + day circles, with
/// one accented (selected) day. [firstCol] is the 0-based column (0=Mon) of
/// day 1; [total] is the number of days in the month.
///
/// Rows are 28 high with 3 between them, as the design lays them out — a
/// square grid cell made every week about twice as tall as drawn.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.firstCol,
    required this.total,
    this.accentDay,
    this.onDayTap,
  });

  final int firstCol;
  final int total;
  final int? accentDay;
  final ValueChanged<int>? onDayTap;

  static const _headers = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cells = <int?>[
      for (var i = 0; i < firstCol; i++) null,
      for (var day = 1; day <= total; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weeks = cells.length ~/ 7;

    Widget cell(int? day) {
      if (day == null) return const SizedBox(height: 28);
      final isAccent = day == accentDay;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDayTap == null ? null : () => onDayTap!(day),
        child: SizedBox(
          height: 28,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAccent ? colors.accent : Colors.transparent,
              ),
              child: Text(
                '$day',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: AppText.sans(
                  size: 17,
                  weight: FontWeight.w700,
                  height: 1,
                  color: isAccent ? Colors.white : colors.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              for (final h in _headers)
                Expanded(
                  child: Text(
                    h,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 11,
                      weight: FontWeight.w800,
                      color: colors.textDim,
                    ),
                  ),
                ),
            ],
          ),
        ),
        for (var w = 0; w < weeks; w++)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++) Expanded(child: cell(cells[w * 7 + c])),
              ],
            ),
          ),
      ],
    );
  }
}
