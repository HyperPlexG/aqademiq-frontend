// Re-tapping the tab you are already on must not tick.
//
// Guide §5 lists this among the rules to assert, and it is the one that does
// NOT live in the governor: a re-tap is a real interaction that simply is not a
// *change*, so the guard belongs at the call site in `AppShell._onTap`. Spec §7
// gives the Shell a budget of exactly 1 — "tab change" — with "re-tapping the
// tab already active" named as explicitly zero.
//
// Worth a real widget test rather than a unit one, because the thing that could
// break it is someone dropping the `index != currentIndex` check while
// refactoring the shell, and nothing else in the suite would notice.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/features/shell/presentation/app_shell.dart';
import 'package:aqademiq/services/haptics/haptic_patterns.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <HapticEvent>[];

  @override
  void emit(HapticEvent event, {int? rampStep}) => events.add(event);
}

/// The real shell, with the five branches stubbed down to a label each. The
/// branch count and order matter — `NavTab` indices run 0–4 and `goBranch`
/// needs every one of them to exist.
GoRouter _shellRouter() {
  StatefulShellBranch stub(String path, String label) => StatefulShellBranch(
        routes: [
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Center(child: Text(label))),
          ),
        ],
      );

  return GoRouter(
    initialLocation: '/subjects',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          stub('/subjects', 'SUBJECTS'), // 0
          stub('/plan', 'PLAN'), //         1
          stub('/timer', 'TIMER'), //       2
          stub('/stats', 'STATS'), //       3
          stub('/ada', 'ADA'), //           4
        ],
      ),
    ],
  );
}

Future<_RecordingHaptics> _pumpShell(WidgetTester tester) async {
  final haptics = _RecordingHaptics();
  final router = _shellRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(haptics),
        // Pinned rather than left to the mock auth stream: a guest is routed
        // away from Ada and Stats before the tab ever changes, which is a
        // different path and not what this file is about.
        isGuestProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme:
            buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return haptics;
}

Future<void> _tapTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a tab change ticks once; re-tapping the same tab is silent',
      (tester) async {
    final haptics = await _pumpShell(tester);

    expect(find.text('SUBJECTS'), findsOneWidget);
    expect(
      haptics.events,
      isEmpty,
      reason: 'never greet someone with a buzz on launch (§4.5)',
    );

    await _tapTab(tester, Icons.calendar_today_outlined);
    expect(find.text('PLAN'), findsOneWidget);
    expect(haptics.events, [HapticEvent.segmentChange]);

    await _tapTab(tester, Icons.calendar_today_outlined);
    expect(
      haptics.events,
      [HapticEvent.segmentChange],
      reason: 're-tapping the active tab is explicitly zero (§7, Shell)',
    );

    await _tapTab(tester, Icons.menu_book_outlined);
    expect(find.text('SUBJECTS'), findsOneWidget);
    expect(
      haptics.events,
      [HapticEvent.segmentChange, HapticEvent.segmentChange],
      reason: 'moving back is a change again',
    );
  });

  testWidgets('the tick is the only thing the shell ever fires', (tester) async {
    // Shell's budget is 1. Walking every tab must not surface a second event
    // type from somewhere else in the tree.
    final haptics = await _pumpShell(tester);

    for (final icon in [
      Icons.calendar_today_outlined,
      Icons.timer_outlined,
      Icons.bar_chart_outlined,
      Icons.menu_book_outlined,
    ]) {
      await _tapTab(tester, icon);
    }

    expect(haptics.events, hasLength(4));
    expect(
      haptics.events.toSet(),
      {HapticEvent.segmentChange},
      reason: 'one event type reachable from the shell, and one only',
    );
  });
}
