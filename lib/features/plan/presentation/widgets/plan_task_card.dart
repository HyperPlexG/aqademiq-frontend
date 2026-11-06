import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/tag.dart';
import '../../../../data/models/tag_resolve.dart';
import '../../../../data/models/task.dart';
import '../../../../shared/widgets/ic.dart';

/// A single task row (v11 `PlanTask`): optional left color bar, the 17/800
/// title, an inline meta line (time 13/800 · tag 12/800 · duration 13), and a
/// tappable done circle. The inline tag is a borderless dot + colored label
/// (not the bordered `TagChip`).
class PlanTaskCard extends StatelessWidget {
  const PlanTaskCard({
    super.key,
    required this.task,
    this.tag,
    this.showBar = false,
    this.showTime = false,
    this.onToggleDone,
    this.onTap,
  });

  final Task task;
  final Tag? tag;
  final bool showBar;

  /// List grouping: a timed task carries its "11:30 AM → 12:00 PM" span on the
  /// meta line (the timeline shows the time above the card instead).
  final bool showTime;
  final VoidCallback? onToggleDone;
  final VoidCallback? onTap;

  String? get _timeSpan {
    final start = task.startTime;
    if (start == null) return null;
    final dur = task.durationMin;
    if (dur == null || dur <= 0) return AppDate.time12h(start);
    return '${AppDate.time12h(start)} → ${AppDate.time12h(start.add(Duration(minutes: dur)))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tagColor = tag != null ? hexColor(tag!.color) : colors.accent;
    final tagLabel = studyTagLabel(tag, task.tagId);
    final time = showTime ? _timeSpan : null;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: task.done ? 0.5 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: colors.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBar) ...[
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: AppText.sans(
                          size: 17,
                          weight: FontWeight.w800,
                          height: 1.25,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (time != null)
                            Text(
                              time,
                              style: AppText.sans(size: 13, weight: FontWeight.w800, color: colors.text),
                            ),
                          PlanInlineTag(label: tagLabel, color: tagColor),
                          if (task.durationMin != null)
                            Text(
                              '${task.durationMin}m',
                              style: AppText.sans(size: 13, color: colors.textDim),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 11 to the circle as drawn: its 6 of touch padding hangs into
                // the gap on the left and into the card padding on the right.
                const SizedBox(width: 5),
                Center(
                  child: Transform.translate(
                    offset: const Offset(6, 0),
                    child: _DoneCircle(done: task.done, onTap: onToggleDone),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The borderless 6 dot + 12/800 coloured tag label on a task card.
class PlanInlineTag extends StatelessWidget {
  const PlanInlineTag({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppText.sans(size: 12, weight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}

class _DoneCircle extends StatelessWidget {
  const _DoneCircle({required this.done, this.onTap});
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Mark as not done' : 'Mark as done',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 22 drawn, with room around it so the circle is not a 22pt target.
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? colors.accent : Colors.transparent,
              border: Border.all(
                color: done ? colors.accent : (dark ? const Color(0xFFD6D3CE) : colors.text),
                width: 2,
              ),
            ),
            child: done ? const Ic('check', size: 16, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}
