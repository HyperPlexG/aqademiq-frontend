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
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
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
    // Silent on purpose. Shell's budget is 1 (§7) and it is spent on the tab
    // change; this branch only navigates, which §4.1 puts firmly at zero. It is
    // also not the Tier 4 "guest-locked wall" — that one is a 403 coming back
    // from a write the user actually attempted, not a pre-emptive gate.
    if (guest && index == NavTab.ada) {
      unawaited(context.push(Routes.guestAda));
      return;
    }
    if (guest && index == NavTab.stats) {
      unawaited(context.push(Routes.guestStats));
      return;
    }
    // The faintest tick in the system, and only on an actual change —
    // re-tapping the active tab pops its branch to root and is explicitly zero.
    if (index != navigationShell.currentIndex) {
      ref.read(hapticsProvider).segmentChange();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
