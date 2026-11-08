import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../shared/widgets/bottom_nav.dart';

/// The 5-tab shell: an indexed-stack body + the floating [BottomNav]. Guest
/// taps on Ada / Stats open a setup prompt instead of navigating (README §5).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final guest = ref.watch(isGuestProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            navigationShell,
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  // v11: the bar floats 22 clear of the sides.
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  child: BottomNav(
                    currentIndex: navigationShell.currentIndex,
                    guest: guest,
                    onTap: (index) => _onTap(ref, context, index, guest: guest),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
