import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../freeze/presentation/widgets/fz_widgets.dart';

// The pieces the Plan pickers share (v11 `PickerSheet`, `CenterDialog`,
// `OptRow`, `SetPill`, `StepBtn`): a sheet that floats 8 clear of the edges,
// a 22 title with the quiet ✕, option rows, and the centred dialog the
// "Set →" rows open.

/// Presents [builder] in the v11 floating sheet over the dimmed screen.
Future<T?> showPlanSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color scrim = AppScrim.picker,
  EdgeInsets padding = const EdgeInsets.fromLTRB(18, 6, 18, 34),
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: scrim,
    builder: (sheetContext) => FzSheet(padding: padding, child: builder(sheetContext)),
  );
}

/// Presents [child] as the v11 centred dialog (`CenterDialog`).
Future<T?> showPlanDialog<T>(BuildContext context, {required Widget child}) {
  return showDialog<T>(
    context: context,
    barrierColor: AppScrim.dialog,
    builder: (_) => child,
  );
}

/// The quiet ✕ (BarDismiss `tight`): a bare 20 glyph, right-aligned on the
/// content edge, in a 34 target.
class PlanDismiss extends StatelessWidget {
  const PlanDismiss({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      excludeSemantics: true,
      onTap: onTap ?? () => unawaited(Navigator.of(context).maybePop()),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => unawaited(Navigator.of(context).maybePop()),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Align(
            alignment: Alignment.centerRight,
            child: Ic('close', size: 20, color: context.colors.textMed),
          ),
        ),
      ),
    );
  }
}

/// A 22/800 sheet or dialog title with the ✕ beside it, and an optional 15
/// sub-line.
class PlanSheetTitle extends StatelessWidget {
  const PlanSheetTitle(this.title, {super.key, this.sub, this.size = 22, this.bottom = 12});

  final String title;
  final String? sub;
  final double size;

  /// Space under the block: the sheet's 12, or the dialog's 14.
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: AppText.sans(size: size, weight: FontWeight.w800, color: colors.text),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const PlanDismiss(),
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                sub!,
                style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
              ),
            ),
        ],
      ),
    );
  }
}

/// One option in a picker sheet (v11 `OptRow`): 52 min, icon 19, label 17
/// (accent 800 when chosen, on accent-soft), optional 13 sub-line, and a check
/// or a trailing widget.
class PlanOptRow extends StatelessWidget {
  const PlanOptRow({
    super.key,
    required this.icon,
    required this.label,
    this.sub,
    this.trailing,
    this.active = false,
    this.onTap,
  });

  /// A design icon name (`all_inclusive`).
  final String icon;
  final String label;
  final String? sub;
  final Widget? trailing;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Ic(icon, size: 19, color: active ? colors.accent : colors.textMed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.sans(
                        size: 17,
                        weight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? colors.accent : colors.text,
                      ),
                    ),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(sub!, style: AppText.sans(size: 13, color: colors.textDim)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ] else if (active) ...[
                const SizedBox(width: 10),
                Ic('check', size: 20, color: colors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The trailing "Set →" pill (v11 `SetPill`), or the value already set.
class PlanSetPill extends StatelessWidget {
  const PlanSetPill({super.key, this.label});

  /// Shown when a value is already chosen; otherwise the "Set →" prompt.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = label != null;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? colors.accent : colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label ?? 'Set →',
        style: AppText.sans(
          size: 15,
          weight: active ? FontWeight.w800 : FontWeight.w700,
          color: active ? Colors.white : colors.textMed,
        ),
      ),
    );
  }
}

/// A 36-high quick chip: accent when chosen, a well otherwise.
class PlanQuickChip extends StatelessWidget {
  const PlanQuickChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.size = 13,
    this.expand = false,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final double size;

  /// Fill the width it is given (the dialog's even row of chips).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: expand ? 4 : 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.accent : colors.bg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppText.sans(
                size: size,
                weight: active ? FontWeight.w800 : FontWeight.w700,
                color: active ? Colors.white : colors.textMed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 50 ink CTA a picker sheet or dialog ends with.
class PlanCta extends StatelessWidget {
  const PlanCta({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: colors.ink,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 50,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sans(size: 17, weight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The centred dialog card (v11 `CenterDialog`): [width] wide (never wider
/// than the screen allows), radius 24, a 22 title with ✕, a 15 sub-line, the
/// body, and the ink CTA.
class PlanCenterDialog extends StatelessWidget {
  const PlanCenterDialog({
    super.key,
    required this.title,
    required this.child,
    required this.ctaLabel,
    required this.onCta,
    this.sub,
    this.width = 252,
  });

  final String title;
  final String? sub;
  final Widget child;
  final String ctaLabel;
  final VoidCallback onCta;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxWidth = MediaQuery.sizeOf(context).width - 32;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: width > maxWidth ? maxWidth : width,
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x57000000), blurRadius: 64, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PlanSheetTitle(title, sub: sub, bottom: 14),
              child,
              const SizedBox(height: 16),
              PlanCta(label: ctaLabel, onTap: onCta),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 38 round stepper button (v11 `StepBtn`).
class PlanStepButton extends StatelessWidget {
  const PlanStepButton({super.key, required this.icon, required this.onTap, required this.label});

  /// `add` or `remove`.
  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      // excludeSemantics drops the InkWell's own tap action too.
      onTap: onTap,
      child: Material(
        color: colors.bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(child: Ic(icon, size: 20, color: colors.text)),
          ),
        ),
      ),
    );
  }
}
