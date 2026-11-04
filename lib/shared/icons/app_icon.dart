import 'package:flutter/material.dart';

import 'aq_icon.dart';

part 'aq_for_material.g.dart';

/// A drop-in for [Icon] that draws the Aqademiq icon pack (v11).
///
/// Call sites keep naming Material icons (`AppIcon(Icons.schedule)`); the ones
/// the pack covers are drawn from it, the rest stay Material — the same rule
/// the prototype's `Ic` follows. The map is generated from the icons `lib/`
/// actually uses (`tool/generate_aq_for_material.js`); re-run it after using a
/// new one, or it simply stays Material.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// The aq name drawn for [icon], or null when it stays Material.
  static String? aqNameFor(IconData? icon) => icon == null ? null : _aqForMaterial[icon];

  @override
  Widget build(BuildContext context) {
    final aq = aqNameFor(icon);
    if (aq == null) return Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
    return AqIcon.named(
      aq,
      size: size ?? IconTheme.of(context).size ?? 24,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}
