import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/icons/app_icon.dart';
import '../../../../shared/widgets/ic.dart';

/// Pill control on the Focus header (v11 `FocusPill` → `BarPill fill="well"`):
/// 44 high, a well pill (closed) or `accentSoft` (open), with a leading icon in
/// the accent — Prism on the left, App freeze on the right.
class FocusPill extends StatelessWidget {
  const FocusPill({super.key, this.glyph, this.icon, this.iconName, required this.label, this.open = false, this.onTap});

  final String? glyph;
  final IconData? icon;

  /// A design icon name (`prism`, `ac_unit`) — preferred over [icon].
  final String? iconName;
  final String label;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = open ? colors.accent : colors.text;
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: EdgeInsets.only(left: glyph != null || icon != null || iconName != null ? 15 : 18, right: 18),
          decoration: BoxDecoration(
            color: open ? colors.accentSoft : colors.bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: open ? colors.accent.alpha8(0x55) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconName != null)
                Ic(iconName!, size: 19, color: colors.accent)
              else if (glyph != null)
                Text(glyph!, style: TextStyle(fontSize: 17, color: colors.accent, height: 1))
              else if (icon != null)
                AppIcon(icon, size: 19, color: colors.accent),
              const SizedBox(width: 6),
              // Ellipsise rather than overflow: at large accessibility text scales
              // the two pills together exceeded the screen width.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(size: 17, weight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
