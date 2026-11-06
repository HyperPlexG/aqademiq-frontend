import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';
import '../../providers/plan_ui_providers.dart';

/// The action the user picked from the Plan overflow (`···`) popover.
enum PlanMenuResult {
  /// "Reschedule tasks" → opens the reschedule-remaining review.
  reschedule,

  /// "Log mood" → opens the mood check-in sheet.
  logMood,

  /// Grouping options → "List" grouping.
  groupingList,

  /// Grouping options → "Timeline" grouping (current selection).
  groupingTimeline,
}

/// Presents the per-day Plan overflow menu (`plan-menu` / `plan-grouping`): a
/// 220-wide white popover anchored to the top-right, dropped from the `···`
/// button. The "Grouping options" header expands to reveal List / Timeline.
///
/// [currentGrouping] drives which option shows the checkmark (must match the
/// live [planViewModeProvider] value — previously Timeline was hardcoded).
///
/// Returns the chosen [PlanMenuResult], or `null` when dismissed.
Future<PlanMenuResult?> showPlanMenu(
  BuildContext context, {
  PlanViewMode currentGrouping = PlanViewMode.timeline,
  bool canLogMood = true,
}) {
  return showDialog<PlanMenuResult>(
    context: context,
    barrierColor: const Color(0x2E140F1C),
    builder: (_) => _PlanMenuPopover(currentGrouping: currentGrouping, canLogMood: canLogMood),
  );
}

class _PlanMenuPopover extends StatefulWidget {
  const _PlanMenuPopover({required this.currentGrouping, required this.canLogMood});

  final PlanViewMode currentGrouping;

  /// False while the planner is showing a day that has not happened yet.
  final bool canLogMood;

  @override
  State<_PlanMenuPopover> createState() => _PlanMenuPopoverState();
}

class _PlanMenuPopoverState extends State<_PlanMenuPopover> {
  bool _groupingOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // With the grouping open, the actions above step back (v11 plan-grouping).
    final dimActions = _groupingOpen;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 40, right: 12),
        // The surface colour lives on the Material itself: the rows' ripples
        // paint on it, and under the opaque Container it used to sit beneath
        // they were never seen. The shadow stays outside, on its own box.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                blurRadius: 44,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Container(
              // 220 as drawn; a longer label (large text) widens it up to 300,
              // then ellipsizes.
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MenuRow(
                      icon: 'event_note',
                      label: 'Reschedule tasks',
                      dimmed: dimActions,
                      onTap: () => Navigator.of(context).pop(PlanMenuResult.reschedule),
                    ),
                    // Hidden while the planner is showing a future day. This
                    // logs against the *selected* date, so on a Thursday viewing
                    // Saturday it wrote a Saturday mood — a day that has not
                    // happened, which then draws a tinted band in the weekly
                    // report and is silently overwritten by the real check-in.
                    if (widget.canLogMood)
                      _MenuRow(
                        icon: 'favorite_border',
                        label: 'Log mood',
                        dimmed: dimActions,
                        onTap: () => Navigator.of(context).pop(PlanMenuResult.logMood),
                      ),
                    if (!_groupingOpen) _Divider(color: colors.border, vertical: 6),
                    _GroupingHeader(
                      open: _groupingOpen,
                      onTap: () => setState(() => _groupingOpen = !_groupingOpen),
                    ),
                    if (_groupingOpen) ...[
                      _Divider(color: colors.border, vertical: 4),
                      _GroupingOption(
                        icon: 'list_view',
                        label: 'List',
                        selected: widget.currentGrouping == PlanViewMode.list,
                        onTap: () => Navigator.of(context).pop(PlanMenuResult.groupingList),
                      ),
                      _GroupingOption(
                        icon: 'planner',
                        label: 'Timeline',
                        selected: widget.currentGrouping == PlanViewMode.timeline,
                        onTap: () => Navigator.of(context).pop(PlanMenuResult.groupingTimeline),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color, required this.vertical});

  final Color color;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, margin: EdgeInsets.symmetric(vertical: vertical), color: color);
  }
}

/// A popover action row: icon 19 + 17/600 label.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dimmed = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: dimmed ? 10 : 11),
          child: Row(
            children: [
              Ic(icon, size: 19, color: colors.text),
              const SizedBox(width: 13),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(size: 17, color: colors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Grouping options" header row that toggles the expanded group.
class _GroupingHeader extends StatelessWidget {
  const _GroupingHeader({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Grouping options',
                maxLines: 1,
                softWrap: false,
                style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
              ),
            ),
            const SizedBox(width: 10),
            Ic(open ? 'chevron_down' : 'chevron_right', size: 18, color: colors.text),
          ],
        ),
      ),
    );
  }
}

/// A grouping choice inside the expanded group ("List" / "Timeline"): the
/// chosen one leads with an accent check and reads 800.
class _GroupingOption extends StatelessWidget {
  const _GroupingOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            children: [
              if (selected) ...[
                Ic('check', size: 18, color: colors.accent),
                const SizedBox(width: 12),
              ],
              Ic(icon, size: 19, color: colors.text),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(
                    size: 17,
                    weight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
