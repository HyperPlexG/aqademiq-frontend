import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import 'ic.dart';

/// The "Guest" pill in the header cluster while in guest mode (v11 guest-home /
/// guest-subjects: a page-fill `BarPill`, 44 high, the guest glyph in warn).
class GuestBadge extends StatelessWidget {
  const GuestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Guest mode',
      child: Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(15, 0, 18, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: colors.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic('guest', size: 19, color: colors.warn),
            const SizedBox(width: 6),
            Text(
              'Guest',
              style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
            ),
          ],
        ),
      ),
    );
  }
}
