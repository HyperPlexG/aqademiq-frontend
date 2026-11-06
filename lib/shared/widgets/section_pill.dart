import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import '../icons/app_icon.dart';
import 'ic.dart';

/// Centered ink pill section header (v11 `SectionPill`):
/// `icon · LABEL (count) ⌄`, white-on-ink.
class SectionPill extends StatelessWidget {
  const SectionPill({
    super.key,
    required this.label,
    this.count,
    this.icon,
    this.onTap,
  });

  final String label;
  final int? count;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = count != null ? '$label ($count)' : label;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          decoration: BoxDecoration(
            color: colors.ink,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: 15, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
              ],
              Text(
                text.toUpperCase(),
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w800,
                  letterSpacing: AppText.em(0.1, 12),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Ic('chevron_down', size: 17, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
