import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/scroll_fade.dart';

/// The 5-tab shell: an indexed-stack body + the floating [BottomNav]. Guest
/// taps on Ada / Stats open a setup prompt instead of navigating (README §5).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final guest = ref.watch(isGuestProvider);
    // The bar steps aside while the keyboard is up: otherwise it rides the
    // resized body up and parks between the focused field and the keyboard.
    final navVisible = MediaQuery.viewInsetsOf(context).bottom <= 0;
    // Measured here, outside the Scaffold, against the real screen insets.
    final navBottom = BottomNav.bottomOffsetOf(context);
    // v11 BNav fade: the page colour, solid up to the bar's midline and
    // easing out [navFadeRun] above it. Ada runs her own fades.
    final fadeSolid = navBottom + BottomNav.height / 2;

    return Scaffold(
      backgroundColor: colors.page,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: BottomNavScope(visible: navVisible, child: navigationShell),
            ),
          ),
          if (navVisible) ...[
            if (navigationShell.currentIndex != NavTab.ada)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EdgeFade.bottom(height: fadeSolid + navFadeRun, solid: fadeSolid),
              ),
            Positioned(
              left: BottomNav.sideInset,
              right: BottomNav.sideInset,
              bottom: navBottom,
              child: BottomNav(
                currentIndex: navigationShell.currentIndex,
                guest: guest,
                onTap: (index) => _onTap(ref, context, index, guest: guest),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// How far the nav's scroll fade eases out above the bar's midline (v11
  /// `BNav`: solid to 52, clear by 116).
  static const double navFadeRun = 64;

  void _onTap(WidgetRef ref, BuildContext context, int index, {required bool guest}) {
    // Guest gating: Ada / Stats open a full-screen setup prompt (README §5).
    //
    // A locked tab knocks at 60%: something solid is there, it just isn't open
    // yet. Gentler than an error.
    if (guest && index == NavTab.ada) {
      ref.read(hapticsProvider).play(HapticMoment.tabLocked);
      unawaited(context.push(Routes.guestAda));
      return;
    }
    if (guest && index == NavTab.stats) {
      ref.read(hapticsProvider).play(HapticMoment.tabLocked);
      unawaited(context.push(Routes.guestStats));
      return;
    }
    // A tick confirms the switch without looking down; Ada's centre tab is a
    // clink, because she is a cube. Only on an actual change — re-tapping the
    // active tab pops its branch to root and stays silent.
    if (index != navigationShell.currentIndex) {
      ref.read(hapticsProvider).play(index == NavTab.ada ? HapticMoment.tabAda : HapticMoment.tabSwitch);
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
