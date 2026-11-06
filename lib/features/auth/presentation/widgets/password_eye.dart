import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/ic.dart';

/// The show/hide toggle inside a password field (v11 `hidden` glyph, 21, muted).
class PasswordEye extends StatelessWidget {
  const PasswordEye({super.key, required this.obscured, required this.onTap});

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscured ? 'Show password' : 'Hide password',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(child: Ic(obscured ? 'hidden' : 'visible', size: 21, color: context.colors.textMed)),
        ),
      ),
    );
  }
}
