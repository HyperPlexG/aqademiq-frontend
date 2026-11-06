import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';

/// A single-line option pill in a settings sheet (v11 `OptionRow`): 50 high,
/// hilite until chosen, then accent-soft with an accent edge and a filled
/// check. Gender, notification sound, the default Prism mode.
class SettingsOptionRow extends StatelessWidget {
  const SettingsOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? colors.accentSoft : colors.hilite,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(width: 1.5, color: selected ? colors.accent : Colors.transparent),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 17, weight: FontWeight.w700, color: selected ? colors.accent : colors.text),
                  ),
                ),
                if (selected) Ic('check_circle:fill', size: 20, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An option card with an icon and a sub-line (v11 `APPEARANCE_PICKER`):
/// radius 16, 21 icon, 17/700 label, 15 sub, a 22 filled check when chosen.
class SettingsOptionCard extends StatelessWidget {
  const SettingsOptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  /// A design icon name (`Ic`).
  final String icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.hilite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? colors.accent : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Ic(icon, size: 21, color: selected ? colors.accent : colors.text),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.sans(size: 17, weight: FontWeight.w700, color: selected ? colors.accent : colors.text),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.35, color: colors.textMed),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Ic('check_circle:fill', size: 22, color: colors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
