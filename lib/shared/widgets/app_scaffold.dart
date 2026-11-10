import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'bottom_nav.dart';
import 'scroll_fade.dart';

/// Standard screen body wrapper: top safe area + 16px side padding + bottom
/// clearance so content clears the floating bottom nav (README §4), and the
/// design's top scroll fade wherever the page's list scrolls up under its
/// header ([ScrollEdgeFades]). The bottom fade behind the nav is drawn once,
/// by the shell.
///
/// A page whose list should run on under the nav (as the design draws every
/// tab) passes `bottomClearance: 0` and pads the end of its scroll view with
/// [navClearanceOf] instead, so the last row can still scroll clear of the bar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.horizontalPadding = AppSpacing.screenSide,
    this.bottomClearance,
    this.top = true,
    this.topFade = true,
  });

  /// Breathing room above the floating nav so primary actions never tuck under
  /// it.
  static const double navBreathing = 20;

  /// What is left between content and the keyboard while the nav is hidden.
  static const double keyboardGap = 8;

  final Widget child;
  final double horizontalPadding;

  /// Bottom inset for the body. Defaults to [navClearanceOf] (the real nav
  /// footprint incl. the home-indicator inset) when null.
  final double? bottomClearance;
  final bool top;

  /// Lay the top scroll-edge fade over the page's scrolling list.
  final bool topFade;

  /// Vertical space the floating [BottomNav] occupies measured from the
  /// physical screen bottom: the bar's offset (which accounts for the home
  /// indicator / Android navigation bar) + bar height + breathing. Single
  /// source of truth for "clear the nav" on every screen.
  ///
  /// While the keyboard is up the shell hides the bar (and the shell's body
  /// already ends at the keyboard), so this drops to [keyboardGap].
  static double navClearanceOf(BuildContext context) {
    if (BottomNavScope.visibleOf(context) == false) return keyboardGap;
    return BottomNav.bottomOffsetOf(context) + BottomNav.height + navBreathing;
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      bottom: false,
      top: top,
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: bottomClearance ?? navClearanceOf(context),
        ),
        child: child,
      ),
    );
    return topFade ? ScrollEdgeFades(child: body) : body;
  }
}
