import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';

/// The light `hilite` section pill on the Plan timeline (v11 `CollapseHead`):
/// optional leading icon, "LABEL (count)" 13/800, and the chevron — down while
/// open, up while collapsed. Distinct from the ink `SectionPill`.
class CollapseHead extends StatelessWidget {
  const CollapseHead({
    super.key,
    required this.label,
    required this.count,
    required this.open,
    this.icon,
    this.onTap,
  });

  final String label;
  final int count;
  final bool open;

  /// A design icon name (`schedule`), drawn from the icon pack.
  final String? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final padding = icon != null
        ? const EdgeInsets.fromLTRB(7, 6, 13, 6)
        : const EdgeInsets.symmetric(horizontal: 15, vertical: 7);

    return Center(
      child: Semantics(
        button: onTap != null,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: colors.hilite,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Ic(icon!, size: 19, color: colors.textMed),
                  const SizedBox(width: 7),
                ],
                Text(
                  '$label ($count)',
                  style: AppText.sans(
                    size: 13,
                    weight: FontWeight.w800,
                    letterSpacing: AppText.em(0.05, 13),
                    color: colors.text,
                  ),
                ),
                const SizedBox(width: 7),
                Ic(open ? 'expand_more' : 'expand_less', size: 18, color: colors.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
