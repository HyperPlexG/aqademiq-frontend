import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/guest_badge.dart';
import '../../../../shared/widgets/ic.dart';

/// v11 `PlanHeader`: day (17/800) + month (12/800, the calendar button), and
/// the action capsule (overflow ··· and add +, 36 slots in a 44 pill). A 44
/// "Today" pill appears when viewing another day.
class PlanHeader extends StatelessWidget {
  const PlanHeader({
    super.key,
    required this.date,
    required this.isToday,
    this.guest = false,
    this.onMonthTap,
    this.onToday,
    this.onMenu,
    this.onAdd,
  });

  final DateTime date;
  final bool isToday;
  final bool guest;
  final VoidCallback? onMonthTap;
  final VoidCallback? onToday;
  final VoidCallback? onMenu;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Pick a month',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMonthTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppDate.weekdayFull(date),
                      style: AppText.sans(
                        size: 17,
                        weight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.1,
                        color: colors.text,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppDate.monthYearUpper(date),
                            style: AppText.sans(
                              size: 12,
                              weight: FontWeight.w800,
                              letterSpacing: AppText.em(0.04, 12),
                              color: colors.textMed,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Ic('chevron_right', size: 14, color: colors.textMed),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isToday) ...[
            _TodayPill(onTap: onToday),
            const SizedBox(width: 7),
          ],
          if (guest) ...[
            const GuestBadge(),
            const SizedBox(width: 7),
          ],
          _ActionCapsule(onMenu: onMenu, onAdd: onAdd),
        ],
      ),
    );
  }
}

/// BarPill "Today": 44 high, white on the page with the card shadow, 17/700.
class _TodayPill extends StatelessWidget {
  const _TodayPill({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: colors.cardShadow,
          ),
          child: Text(
            'Today',
            style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
          ),
        ),
      ),
    );
  }
}

class _ActionCapsule extends StatelessWidget {
  const _ActionCapsule({this.onMenu, this.onAdd});
  final VoidCallback? onMenu;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CircleTap(
            label: 'More',
            onTap: onMenu,
            child: Ic('more', color: colors.text),
          ),
          const SizedBox(width: 2),
          _CircleTap(
            label: 'Add a task',
            onTap: onAdd,
            child: Ic('add', color: colors.text),
          ),
        ],
      ),
    );
  }
}

class _CircleTap extends StatelessWidget {
  const _CircleTap({required this.child, required this.label, this.onTap});
  final Widget child;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }
}
