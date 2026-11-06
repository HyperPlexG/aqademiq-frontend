import 'package:flutter/material.dart';

import '../../../../shared/icons/aq_icon.dart';

/// What leads a study-tag chip (v11 `TagChip` / HomeBody): the pack's Tier 2
/// task glyph for a tag it knows by name ("Exam", "Lecture", …), else the
/// tag's colour dot. On light surfaces the glyph is drawn in the ink step of
/// the tag's hue; on dark ones in the hue itself, as the design does.
class StudyTagMark extends StatelessWidget {
  const StudyTagMark({super.key, required this.label, required this.color, this.size = 18, this.dot = 7});

  final String label;
  final Color color;
  final double size;

  /// The dot's diameter when the tag has no glyph.
  final double dot;

  /// The ink step for a palette hue, when [color] is one of the pack's tag
  /// hues.
  static Color? _inkFor(Color color) {
    for (final t in AqTaskIcons.byLabel.values) {
      if (t.hue == color) return t.ink;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final task = AqTaskIcons.byLabel[label.trim()];
    if (task == null) {
      return Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AqTaskIcon(task, size: size, color: dark ? color : (_inkFor(color) ?? task.ink));
  }
}
