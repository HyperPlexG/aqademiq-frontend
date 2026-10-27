import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';

/// A filter / choice pill on the import screens (calendars, range, tag).
/// Selected = accent outline on the soft accent fill, like the Plan's chips.
class ImportChip extends StatelessWidget {
  const ImportChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The calendar's or tag's own colour, drawn as a dot before the label.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = dotColor;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.fromLTRB(dot == null ? 12 : 10, 7, 12, 7),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w700,
                    color: selected ? colors.accent : colors.text,
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

/// The tick on an import row. [locked] = already in the plan (cannot untick).
class ImportCheckCircle extends StatelessWidget {
  const ImportCheckCircle({super.key, required this.checked, this.locked = false});

  final bool checked;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = locked ? colors.hilite : (checked ? colors.accent : Colors.transparent);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: locked ? colors.hilite : (checked ? colors.accent : colors.textDim),
          width: 1.5,
        ),
      ),
      child: checked || locked
          ? Icon(Icons.check, size: 14, color: locked ? colors.textMed : Colors.white)
          : null,
    );
  }
}

/// A small status pill on an import row ("In your plan").
class ImportBadge extends StatelessWidget {
  const ImportBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.hilite,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.sans(size: 10.5, weight: FontWeight.w700, color: colors.textMed),
      ),
    );
  }
}

/// The short explanatory line under a heading or a group.
class ImportCaption extends StatelessWidget {
  const ImportCaption(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 18)});

  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: AppText.sans(size: 11.5, height: 1.5, color: context.colors.textMed),
      ),
    );
  }
}
