// The app opens on Focus. `routeAfterAuth` is the landing for a cold launch
// with a saved session (the splash), a sign-in and a guest's mock session;
// it used to go to the Plan. A widget's own destination (`aqademiq://plan`
// parked as the pending launch route) still wins.

import 'dart:async';

import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/core/router/pending_launch_route.dart';
import 'package:aqademiq/features/onboarding/onboarding_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<GoRouter> _land(WidgetTester tester, {String? pending}) async {
  final router = GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () {
              if (pending != null) ref.read(pendingLaunchRouteProvider.notifier).set(pending);
              unawaited(routeAfterAuth(context, ref));
            },
            child: const Text('go'),
          ),
        ),
      ),
      for (final r in [Routes.timer, Routes.plan, Routes.stats]) GoRoute(path: r, builder: (_, _) => Text('at $r')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('home is the Focus tab', () => expect(appHome, Routes.timer));

  testWidgets('after launch or sign-in the app lands on Focus', (tester) async {
    final router = await _land(tester);
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.timer);
    expect(find.text('at ${Routes.timer}'), findsOneWidget);
  });

  testWidgets("a widget's plan intent still opens the Plan", (tester) async {
    final router = await _land(tester, pending: Routes.plan);
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.plan);
  });
}
