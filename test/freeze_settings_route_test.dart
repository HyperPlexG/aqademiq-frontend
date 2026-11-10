// Settings → App freeze → Frosts & groups, through the real router.
//
// The settings page is a root route; the App freeze hub lives inside the
// Focus tab's branch of the StatefulShellRoute. Reaching the hub from
// Settings must land on that branch (bottom nav and all), render the hub, and
// leave the Focus tab working afterwards.

import 'dart:async';

import 'package:aqademiq/app.dart';
import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/features/focus/presentation/timer_screen.dart';
import 'package:aqademiq/features/freeze/data/freeze_store.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/presentation/freeze_group_screen.dart';
import 'package:aqademiq/features/freeze/presentation/freeze_hub_screen.dart';
import 'package:aqademiq/features/freeze/presentation/freeze_setup_screens.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// The page on top: a pushed page keeps the base `uri`, so read the last match.
String _top(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

Future<(ProviderContainer, GoRouter)> _boot(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues({});
  await FreezeStore.instance.init();
  await FreezeStore.instance.write(const FreezeData(setUp: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(const NoopHapticsService()),
      ],
      child: const AqademiqApp(),
    ),
  );
  // Splash → Welcome → guest → the Plan tab.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump();
  await tester.tap(find.text('Jump right in!'));
  await _settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return (container, container.read(routerProvider));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'Frosts & groups from Settings opens the hub, and Focus still opens after',
    (tester) async {
      final (container, router) = await _boot(tester);
      expect(container.read(freezeControllerProvider).setUp, isTrue);

      unawaited(router.push(Routes.settings));
      await _settle(tester);
      unawaited(router.push(Routes.settingsAppFreeze));
      await _settle(tester);
      expect(find.text('Frosts & groups'), findsOneWidget);

      await tester.tap(find.text('Frosts & groups'));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(FreezeHubScreen), findsOneWidget);
      expect(_top(router), Routes.freezeHubSettings);

      // Each group card opens its page under this hub, and back returns to it.
      for (final group in ['Always open', 'Never open', 'Distracting']) {
        await tester.ensureVisible(find.text(group).first);
        await tester.tap(find.text(group).first);
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: group);
        expect(find.byType(FreezeGroupScreen), findsOneWidget, reason: group);
        expect(_top(router), startsWith('${Routes.freezeHubSettings}/'));
        router.pop();
        await _settle(tester);
      }

      // Back from the hub lands on Settings → App freeze, where it came from.
      router.pop();
      await _settle(tester);
      expect(find.text('Frosts & groups'), findsOneWidget);

      // Out of Settings, then Focus: the timer, not a blank page.
      router.go(Routes.plan);
      await _settle(tester);
      router.go(Routes.timer);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(TimerScreen), findsOneWidget);
      expect(_top(router), Routes.timer);

      // And the Focus tab's own door to the hub still works, with its groups.
      unawaited(router.push(Routes.freeze));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(FreezeHubScreen), findsOneWidget);
      for (final path in [
        Routes.freezeAlways,
        Routes.freezeNever,
        Routes.freezeDistract,
      ]) {
        unawaited(router.push(path));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: path);
        expect(find.byType(FreezeGroupScreen), findsOneWidget, reason: path);
        router.pop();
        await _settle(tester);
      }
    },
  );

  testWidgets(
    'Setup hands over to the hub that fits where it was opened from',
    (tester) async {
      final (_, router) = await _boot(tester);

      // From Focus: the intro sits right over the shell → the Focus tab's hub.
      router.go(Routes.timer);
      await _settle(tester);
      unawaited(router.push(Routes.freezeIntro));
      await _settle(tester);
      replaceWithFreezeHub(tester.element(find.byType(FreezeIntroScreen)));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(_top(router), Routes.freeze);
      expect(find.byType(FreezeHubScreen), findsOneWidget);
      router.go(Routes.timer);
      await _settle(tester);
      expect(find.byType(TimerScreen), findsOneWidget);

      // From Settings: the full-screen hub, over Settings.
      unawaited(router.push(Routes.settingsAppFreeze));
      await _settle(tester);
      unawaited(router.push(Routes.freezePermission));
      await _settle(tester);
      replaceWithFreezeHub(tester.element(find.byType(FreezePermissionScreen)));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(_top(router), Routes.freezeHubSettings);
      router.pop();
      await _settle(tester);
      expect(find.text('Frosts & groups'), findsOneWidget);
      router.go(Routes.timer);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(TimerScreen), findsOneWidget);
    },
  );
}
