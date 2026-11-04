import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import '../icons/app_icon.dart';

/// Full-width pill button (v11 `PBtn`: 50 high, 17/800). Filled = ink fill /
/// white text; ghost = surface + hairline border / text color.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.ghost = false,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final IconData? icon;

  /// When `false`, the button renders greyed-out and ignores taps. Defaults to
  /// `true`, so existing call sites are unaffected.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bg = !enabled
        ? colors.hilite
        : (ghost ? colors.surface : colors.ink);
    final fg = !enabled
        ? colors.textDim
        : (ghost ? colors.text : Colors.white);
    final borderRadius = BorderRadius.circular(AppRadius.pill);

    return Material(
      color: bg,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: enabled ? onPressed : null,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: ghost
                ? Border.all(color: colors.border, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AppIcon(icon, size: 21, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.sans(
                    size: 17,
                    weight: FontWeight.w800,
                    letterSpacing: AppText.em(0.01, 17),
                    color: fg,
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
