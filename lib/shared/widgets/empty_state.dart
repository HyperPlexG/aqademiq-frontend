import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text.dart';
import '../mascot/ada_mascot.dart';

/// Friendly empty-state block: Ada in a soft accent circle + a couple of lines
/// of copy + an optional CTA pill. Same recipe as the Subjects-tab empty
/// (FRAMES `subj-list` zero state), extracted so every empty collection in the
/// app reads as one family.
///
/// Ada gently bobs (frozen under reduced motion) and the block fades in with a
/// small rise, so an empty screen feels alive instead of broken. Use
/// [EmptyState.compact] inside bottom sheets and dense panels.
class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.expr = AdaExpr.happy,
    this.sparkles = false,
    this.cheeks = false,
    this.sweat = false,
    this.ctaLabel,
    this.onCta,
    this.ctaIcon = Icons.add,
    this.padding,
  }) : compact = false;

  /// Tighter variant for bottom sheets / embedded panels: smaller mascot,
  /// smaller type, less air.
  const EmptyState.compact({
    super.key,
    required this.title,
    this.subtitle,
    this.expr = AdaExpr.happy,
    this.sparkles = false,
    this.cheeks = false,
    this.sweat = false,
    this.ctaLabel,
    this.onCta,
    this.ctaIcon = Icons.add,
    this.padding,
  }) : compact = true;

  final String title;
  final String? subtitle;

  /// Ada's face for this moment (happy by default; pick per context).
  ///
  /// Lean on these rather than on longer copy — [expr] plus [sparkles],
  /// [cheeks] and [sweat] carry the tone, so the text can stay short.
  final AdaExpr expr;

  /// Draw sparkles behind Ada for celebratory empties ("all done!").
  final bool sparkles;

  /// Blush — warmth for a friendly invitation.
  final bool cheeks;

  /// A sweat bead — mild "oops" for gone / failed states.
  final bool sweat;

  /// When both [ctaLabel] and [onCta] are given, an ink pill button renders
  /// under the copy (e.g. "Add a task" reusing the screen's existing handler).
  final String? ctaLabel;
  final VoidCallback? onCta;
  final IconData? ctaIcon;

  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  // Slow idle bob; drives only a tiny translate, so it's cheap to keep running.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat();
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact = widget.compact;
    final hasCta = widget.ctaLabel != null && widget.onCta != null;

    final mascot = AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -2.5 * math.sin(_bob.value * 2 * math.pi)),
        child: child,
      ),
      child: Container(
        width: compact ? 56 : 78,
        height: compact ? 56 : 78,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.accentSoft, shape: BoxShape.circle),
        child: AdaMascot(
          size: compact ? 34 : 48,
          expr: widget.expr,
          sparkles: widget.sparkles,
          cheeks: widget.cheeks,
          sweat: widget.sweat,
        ),
      ),
    );

    final block = Padding(
      padding: widget.padding ??
          EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 16 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          mascot,
          SizedBox(height: compact ? 12 : 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: AppText.sans(
              size: compact ? 14.5 : 19,
              weight: FontWeight.w700,
              color: colors.text,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: AppText.sans(
                size: compact ? 11.5 : 12,
                height: 1.55,
                color: colors.textMed,
              ),
            ),
          ],
          if (hasCta) ...[
            SizedBox(height: compact ? 14 : 18),
            _EmptyCta(
              label: widget.ctaLabel!,
              icon: widget.ctaIcon,
              compact: compact,
              onTap: widget.onCta,
            ),
          ],
        ],
      ),
    );

    // One-shot entrance: fade in + small rise.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: block,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}

/// Content-hugging ink pill (the Subjects zero-state CTA, shared).
class _EmptyCta extends StatelessWidget {
  const _EmptyCta({
    required this.label,
    required this.compact,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool compact;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: colors.ink,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 18, vertical: 9)
              : const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: Colors.white),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: AppText.sans(
                  size: compact ? 12 : 12.5,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
