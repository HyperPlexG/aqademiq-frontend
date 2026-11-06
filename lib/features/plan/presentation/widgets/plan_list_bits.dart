import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';

/// Empty-bucket "add a task" row (v11 `AddRow`, plan-otherday): a quiet dot,
/// the 17 prompt and a 24 well "+", 52 high.
class AddRow extends StatelessWidget {
  const AddRow({super.key, this.label = 'Add a task for anytime', this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFFD6D3CE) : const Color(0xFFECEBE9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(label, style: AppText.sans(size: 17, color: colors.textDim)),
                ),
                const SizedBox(width: 11),
                AddCircle(onTap: onTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 24 well circle with a "+" that ends an empty row.
class AddCircle extends StatelessWidget {
  const AddCircle({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
        child: Ic('add', size: 16, color: colors.textDim),
      ),
    );
  }
}

/// The empty planner's add line (v11 `IB_EMPTY_PLAN`): the 17 prompt and a
/// bare 21 "+", no dot and no well.
class AddLine extends StatelessWidget {
  const AddLine({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
                ),
              ),
              Ic('add', size: 21, color: colors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tinted group header for the list grouping view (v11 `ListGroupHead`): a
/// centred pill (tint at 18%) with the bucket icon, "LABEL (count)" and a
/// chevron, and a bare "+" at the right edge that adds to that bucket.
class ListGroupHead extends StatelessWidget {
  const ListGroupHead({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    this.tint,
    this.open = true,
    this.onTap,
    this.onAdd,
  });

  /// A design icon name (`wb_twilight`), drawn from the icon pack.
  final String icon;
  final String label;
  final int count;
  final Color? tint;

  /// Down chevron while the group shows its tasks, up while collapsed.
  final bool open;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(11, 6, 13, 6),
              decoration: BoxDecoration(
                color: tint != null ? tint!.alpha8(0x2E) : colors.hilite,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Ic(icon, size: 18, color: colors.textMed),
                  const SizedBox(width: 7),
                  Text(
                    '$label ($count)',
                    style: AppText.sans(
                      size: 13,
                      weight: FontWeight.w800,
                      letterSpacing: AppText.em(0.04, 13),
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Ic(open ? 'chevron_down' : 'expand_less', size: 21, color: colors.text),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Semantics(
              button: true,
              label: 'Add to ${label.toLowerCase()}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAdd,
                child: SizedBox(
                  width: 44,
                  height: 36,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Ic('add', size: 19, color: colors.textDim),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
