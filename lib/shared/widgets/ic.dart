import 'package:flutter/material.dart';

import '../icons/aq_icon.dart';

/// An icon by its design name — the v11 prototype's `<Ic n="…">`.
///
/// Draws from the Aqademiq icon pack (`lib/shared/icons/`, generated from
/// `prototypes/v11/aq-icons.js`) and falls back to Material where the pack has
/// no glyph, exactly as the prototype does. Ice glyphs drawn in the accent are
/// pinned to the ice violet. Names: `freeze`, `thaw`, `never_open`, a Material
/// name such as `schedule`, `name:fill` for the filled variant, or
/// `mi:graphic_eq` to force Material.
class Ic extends StatelessWidget {
  const Ic(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = AqResolvedIcon.parse(name);
    if (resolved.glyph != null) return AqIcon.named(name, size: size, color: color);
    return Icon(materialFor(resolved.materialName ?? name), size: size, color: color);
  }

  /// The Material glyph standing in for [name] — for APIs that take an
  /// [IconData] (`SettingsRow.icon`).
  static IconData materialFor(String name) {
    var n = name;
    final fill = n.endsWith(':fill');
    if (fill) n = n.substring(0, n.length - 5);
    if (n.startsWith('mi:')) n = n.substring(3);
    return (fill ? _filled[n] : null) ?? _map[n] ?? AqMaterialIcons.byName[n] ?? Icons.circle_outlined;
  }

  static const Map<String, IconData> _filled = {
    'check_circle': Icons.check_circle,
    'favorite': Icons.favorite,
    'star': Icons.star,
  };

  static const Map<String, IconData> _map = {
    // App freeze's own words.
    'freeze': Icons.ac_unit,
    'ac_unit': Icons.ac_unit,
    // Icons.waves is what the pack draws as thaw (AQ_MAP), so a SettingsRow
    // handed this IconData still gets the thaw glyph.
    'thaw': Icons.waves,
    'never_open': Icons.block,
    'shield': Icons.shield_outlined,
    'hidden': Icons.visibility_off_outlined,
    'visibility_off': Icons.visibility_off_outlined,
    'cube_cracked': Icons.ac_unit,
    'prism': Icons.graphic_eq,
    'trend': Icons.trending_up,
    'task_exam': Icons.assignment_outlined,
    'forward': Icons.arrow_forward,
    'back': Icons.arrow_back,
    'battery': Icons.battery_alert_outlined,
    'chevron_down': Icons.expand_more,
    // Material names the design uses as is.
    'add': Icons.add,
    'all_inclusive': Icons.all_inclusive,
    'battery_alert': Icons.battery_alert_outlined,
    'bedtime': Icons.bedtime_outlined,
    'calendar_month': Icons.calendar_month_outlined,
    'call': Icons.call_outlined,
    'cancel': Icons.cancel_outlined,
    'center_focus_strong': Icons.center_focus_strong_outlined,
    'chat_bubble': Icons.chat_bubble_outline,
    'check': Icons.check,
    'check_circle': Icons.check_circle_outline,
    'check_circle_outline': Icons.check_circle_outline,
    'chevron_left': Icons.chevron_left,
    'chevron_right': Icons.chevron_right,
    'close': Icons.close,
    'date_range': Icons.date_range_outlined,
    'delete': Icons.delete_outline,
    'description': Icons.description_outlined,
    'do_not_disturb_on': Icons.do_not_disturb_on_outlined,
    'edit': Icons.edit_outlined,
    'error_outline': Icons.error_outline,
    'expand_less': Icons.expand_less,
    'expand_more': Icons.expand_more,
    'graphic_eq': Icons.graphic_eq,
    'hourglass_empty': Icons.hourglass_empty,
    'layers': Icons.layers_outlined,
    'map': Icons.map_outlined,
    'account_balance_wallet': Icons.account_balance_wallet_outlined,
    'pause': Icons.pause,
    'play': Icons.play_arrow,
    'query_stats': Icons.query_stats,
    'refresh': Icons.refresh,
    'remove': Icons.remove,
    'schedule': Icons.schedule,
    'school': Icons.school_outlined,
    'settings': Icons.settings_outlined,
    'timer': Icons.timer_outlined,
    'today': Icons.today_outlined,
    'vibration': Icons.vibration,
    'waves': Icons.waves,
  };
}
