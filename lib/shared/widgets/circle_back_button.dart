import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../icons/app_icon.dart';

/// The circular back button (v11 `BackBtn`): 44, white with the card shadow,
/// the pack's back glyph. One look for every back affordance.
class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, this.onTap, this.icon = Icons.arrow_back});

  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle, boxShadow: colors.cardShadow),
        child: AppIcon(icon, size: 24, color: colors.text),
      ),
    );
  }
}
