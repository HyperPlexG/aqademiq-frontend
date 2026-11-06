import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../icons/aq_icon.dart';
import 'ic.dart';

/// The seven built-in study tags that lead with their Tier 2 task glyph
/// (v11 `AQ_TAG`). Any other tag, and every subject, keeps the dot.
const Set<String> _kGlyphTags = {
  'Lecture',
  'Class',
  'Exam',
  'Assignment',
  'Report',
  'Presentation',
  'Reading',
};

/// Study-tag pill (v11 `TagChip`): a 36-high capsule, 15/600, led by the
/// tag's task glyph (built-in tags) or a dot, with an optional ✕; 1.5 solid or
/// dashed border. Used in forms/Settings (the timeline task row uses a
/// borderless inline tag instead).
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.active = false,
    this.dashed = false,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final Color? color;
  final bool active;
  final bool dashed;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = color;
    final borderColor = dashed
        ? (c ?? colors.textDim)
        : (active ? (c ?? colors.accent) : colors.border);
    final fill = active && c != null
        ? c.alpha8(0x18)
        : (active ? colors.accentSoft : colors.surface);
    final textColor = dashed
        ? (c ?? colors.textMed)
        : (active ? (c ?? colors.accent) : colors.textMed);
    final task = (!dashed && _kGlyphTags.contains(label)) ? AqTaskIcons.byLabel[label] : null;

    Widget? lead;
    if (task != null) {
      lead = AqTaskIcon(task, size: 18, color: dark ? c : null);
    } else if (!dashed && c != null) {
      lead = Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _ChipBorderPainter(border: borderColor, fill: fill, dashed: dashed),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: EdgeInsets.only(left: task != null ? 11 : 14, right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 6)],
                // A long tag ellipsizes instead of overflowing its Wrap row. A
                // cap rather than Flexible: chips also sit in horizontal scroll
                // rows, where there is no bounded width to flex into.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 15, color: textColor),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onRemove,
                    child: Ic('close', size: 16, color: textColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipBorderPainter extends CustomPainter {
  _ChipBorderPainter({required this.border, required this.fill, required this.dashed});

  final Color border;
  final Color fill;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / 2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = border;

    // Inset by half the stroke so the 1.5 border sits inside the 36 capsule.
    final inner = rrect.deflate(0.75);
    if (!dashed) {
      canvas.drawRRect(inner, stroke);
      return;
    }

    final path = Path()..addRRect(inner);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, math.min(dist + dash, metric.length)),
          stroke,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ChipBorderPainter old) =>
      old.border != border || old.fill != fill || old.dashed != dashed;
}
