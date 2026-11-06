/// The v11 building blocks the Subjects screens share (§03): the 44 header
/// buttons, the small caps field label, the 17pt input, and the sheet that
/// floats 8 clear of the edges. Sizes are the design's own.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';

/// HEAD_BTN — every header button is a 44 target.
const double kSubjHeadButton = 44;

/// How a header button is filled (the prototype's `barFill`).
enum SubjFill {
  /// White with the card shadow — on the page.
  page,

  /// Translucent white — on a coloured hero.
  glass,

  /// Solid ink — the primary action in a sheet header ("Save").
  ink,
}

(Color, Color, List<BoxShadow>) _fill(AppColors colors, SubjFill fill) => switch (fill) {
      SubjFill.page => (colors.surface, colors.text, colors.cardShadow),
      SubjFill.glass => (Colors.white.withValues(alpha: 0.24), Colors.white, const <BoxShadow>[]),
      SubjFill.ink => (colors.ink, Colors.white, const <BoxShadow>[]),
    };

/// A 44-high pill header button (BarPill): optional icon, 17/700 label.
class SubjBarPill extends StatelessWidget {
  const SubjBarPill({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.fill = SubjFill.page,
    this.onTap,
    this.enabled = true,
  });

  final String label;

  /// A design icon name (`ios_share`, `edit`).
  final String? icon;
  final Color? iconColor;
  final SubjFill fill;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, shadow) = _fill(context.colors, fill);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            height: kSubjHeadButton,
            padding: EdgeInsets.fromLTRB(icon == null ? 18 : 15, 0, 18, 0),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(kSubjHeadButton / 2),
              boxShadow: shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Ic(icon!, size: 19, color: iconColor ?? fg),
                  const SizedBox(width: 6),
                ],
                Text(label, style: AppText.sans(size: 17, weight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44 circular header button (BarCircle).
class SubjBarCircle extends StatelessWidget {
  const SubjBarCircle({
    super.key,
    required this.icon,
    this.fill = SubjFill.page,
    this.onTap,
    this.semanticLabel,
  });

  /// A design icon name (`arrow_back`, `delete`).
  final String icon;
  final SubjFill fill;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, shadow) = _fill(context.colors, fill);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: kSubjHeadButton,
          height: kSubjHeadButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: shadow),
          child: Ic(icon, size: 22, color: fg),
        ),
      ),
    );
  }
}

/// The ✕ that leaves a sheet (BarDismiss): a bare 20 glyph in a 44 target.
/// [edge] bleeds the target 12 past the content edge so the glyph lines up
/// with the padding, as the design does.
class SubjDismiss extends StatelessWidget {
  const SubjDismiss({super.key, this.onTap, this.edge = AxisDirection.right});

  final VoidCallback? onTap;

  /// Which content edge the button sits against: [AxisDirection.left] or
  /// [AxisDirection.right].
  final AxisDirection edge;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(edge == AxisDirection.left ? -12 : 12, 0),
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).closeButtonTooltip,
        excludeSemantics: true,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: SizedBox.square(
            dimension: kSubjHeadButton,
            child: Center(child: Ic('close', size: 20, color: context.colors.textMed)),
          ),
        ),
      ),
    );
  }
}

/// The small caps label above a field (SLabel): 12/800, 0.12em, DIM.
class SubjLabel extends StatelessWidget {
  const SubjLabel(this.text, {super.key, this.optional = false, this.bottom = 7});

  final String text;

  /// Space under the label; 0 when it shares a row with an action.
  final double bottom;

  /// Appends a quieter "· optional".
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final dim = context.colors.textDim;
    final style = AppText.sans(size: 12, weight: FontWeight.w800, letterSpacing: AppText.em(0.12, 12), color: dim);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text.rich(
        TextSpan(
          text: text.toUpperCase(),
          style: style,
          children: [
            if (optional)
              TextSpan(
                text: ' · OPTIONAL',
                style: AppText.sans(size: 12, letterSpacing: AppText.em(0.12, 12), color: dim),
              ),
          ],
        ),
      ),
    );
  }
}

/// A 17/700 text input on a well (BG) or a card (white + shadow), radius 12.
class SubjInput extends StatelessWidget {
  const SubjInput({
    super.key,
    required this.controller,
    this.hint,
    this.onCard = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  final TextEditingController controller;
  final String? hint;

  /// White with the card shadow instead of the BG well.
  final bool onCard;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: onCard ? colors.surface : colors.bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: onCard ? colors.cardShadow : null,
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        cursorColor: colors.accent,
        style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: padding,
          hintText: hint,
          hintStyle: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.textDim),
        ),
      ),
    );
  }
}

/// The sheet that floats 8 clear of the sides and bottom (SheetPanel):
/// radius 47, the drag handle, then [child]. Lifts above the keyboard.
class SubjSheetPanel extends StatelessWidget {
  const SubjSheetPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 34)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + keyboard),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(47),
          boxShadow: colors.sheetShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DDD7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
