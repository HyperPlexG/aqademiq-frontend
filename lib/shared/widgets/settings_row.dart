import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import '../icons/app_icon.dart';
import 'app_toggle.dart';

/// A label above a [SetGroup] (v11 `GroupLabel`: 17/700, muted).
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 8),
      child: Text(
        text,
        style: AppText.sans(
          size: 17,
          weight: FontWeight.w700,
          color: context.colors.textMed,
        ),
      ),
    );
  }
}

/// Rounded surface container that clips a stack of [SettingsRow]s
/// (prototype `SetGroup`, radius 18).
class SetGroup extends StatelessWidget {
  const SetGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.group),
        boxShadow: colors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// Inset value pill on the right of a row (v11 `TimePill`: 36 high, 17/700).
class TimePill extends StatelessWidget {
  const TimePill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 36,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.hilite,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
      ),
    );
  }
}

/// A settings list row (prototype `SetRow`): optional avatar/icon, label (+sub),
/// optional right-aligned value, then pill / toggle / chevron. When a [toggle]
/// is present and there is no value, the label wraps to 2 lines instead of
/// overlapping the toggle (README §4).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.avatar,
    this.sub,
    this.value,
    this.valueWidget,
    this.iconColor,
    this.pill,
    this.toggle,
    this.onToggle,
    this.showChevron = false,
    this.onTap,
    this.danger = false,
    this.last = false,
  });

  final String label;
  final IconData? icon;
  final Widget? avatar;
  final String? sub;
  final String? value;

  /// A right-aligned widget beside [value] — a status dot and its word.
  final Widget? valueWidget;
  final Color? iconColor;
  final String? pill;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool danger;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelColor = danger ? colors.danger : colors.text;
    // An empty value is no value. Weekly report passes '' while it is on, and
    // the Flexible below took half the row for nothing, leaving its chevron
    // stranded mid-row.
    final hasValue = value != null && value!.isNotEmpty;

    // v11 SetRow: the separator starts at the text, as iOS lists do — past
    // the icon (46) or the avatar (58), else the row's own inset (15).
    final inset = icon != null ? 46.0 : (avatar != null ? 58.0 : 15.0);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        foregroundDecoration: last ? null : _InsetLine(colors.border, inset),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        child: Row(
          children: [
            if (avatar != null) ...[avatar!, const SizedBox(width: 11)],
            if (icon != null) ...[
              AppIcon(icon, size: 20, color: danger ? colors.danger : (iconColor ?? colors.text)),
              const SizedBox(width: 11),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: hasValue ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      size: 17,
                      height: 1.3,
                      color: labelColor,
                    ),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        sub!,
                        style: AppText.sans(
                          size: 15,
                          weight: FontWeight.w500,
                          height: 1.4,
                          color: colors.textMed,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasValue)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      size: 17,
                      weight: FontWeight.w500,
                      color: colors.textMed,
                    ),
                  ),
                ),
              ),
            if (valueWidget != null) ...[const SizedBox(width: 10), valueWidget!],
            if (pill != null) ...[const SizedBox(width: 10), TimePill(pill!)],
            if (toggle != null) ...[
              const SizedBox(width: 10),
              AppToggle(value: toggle!, onChanged: onToggle),
            ],
            if (showChevron) ...[
              const SizedBox(width: 6),
              AppIcon(Icons.chevron_right, size: 19, color: colors.textDim),
            ],
          ],
        ),
      ),
    );
  }
}

/// A 1px hairline along the bottom edge, starting [inset] in from the left.
class _InsetLine extends Decoration {
  const _InsetLine(this.color, this.inset);

  final Color color;
  final double inset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _InsetLinePainter(color, inset);
}

class _InsetLinePainter extends BoxPainter {
  _InsetLinePainter(this.color, this.inset);

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = Rect.fromLTWH(offset.dx + inset, offset.dy + size.height - 1, size.width - inset, 1);
    canvas.drawRect(rect, Paint()..color = color);
  }
}
