// The Focus tab's ice chip (fc-ice) and the sheet behind it.
//
// TestFlight: Android showed "Nothing on ice" while iOS showed no chip at
// all — the chip waited for `setUp`, which an iPhone that allowed Screen Time
// in onboarding but skipped the picks never reached. The chip now follows
// App freeze's availability on both platforms. The sheet ("The usual") lists
// the picks with their icons, as fz-select does: package icons on Android,
// FamilyControls token rows on iOS.

import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/focus/presentation/timer_screen.dart';
import 'package:aqademiq/features/freeze/data/app_freeze_channel.dart';
import 'package:aqademiq/features/freeze/data/freeze_store.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/presentation/widgets/fz_widgets.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokens = ['cat_social', 'app_1', 'app_2', 'app_3', 'app_4', 'app_5', 'app_6', 'app_7'];

/// The fake native side: App freeze supported, Screen Time / the grants as
/// [authorized], and `selectionTokens` answering [_tokens] for the usual.
void _fakeFreezeChannel({required bool authorized}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel(AppFreezeChannel.name),
    (call) async => switch (call.method) {
      'status' => {
        'supported': true,
        'authorized': authorized,
        'usage_access': authorized,
        'overlay': authorized,
        'notifications': true,
      },
      'selectionTokens' => _tokens,
      'installedApps' => [
        {'package': 'com.instagram.android', 'label': 'Instagram'},
        {'package': 'com.google.android.youtube', 'label': 'YouTube'},
      ],
      _ => null,
    },
  );
  // iOS token views are platform views; the framework only needs an answer.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform_views,
    (call) async => null,
  );
}

Future<void> _pumpFocus(WidgetTester tester, FreezeData data) async {
  await FreezeStore.instance.write(data);
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.timer,
    routes: [
      GoRoute(
        path: Routes.timer,
        builder: (_, _) => const Scaffold(body: TimerScreen()),
      ),
      GoRoute(
        path: Routes.freezeIntro,
        builder: (_, _) => const Scaffold(body: Text('FREEZE INTRO')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(const NoopHapticsService())],
      child: MaterialApp.router(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        routerConfig: router,
      ),
    ),
  );
  // The access status arrives over the channel.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 950));
}

/// The timer cube animates for ever, so a sheet or a push is pumped through
/// its transition rather than settled.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await FreezeStore.instance.init();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel(AppFreezeChannel.name), null)
      ..setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets(
    'iOS shows "Nothing on ice" when Screen Time is on but App freeze was never marked set up',
    (tester) async {
      _fakeFreezeChannel(authorized: true);
      await _pumpFocus(tester, const FreezeData());

      expect(find.text('Nothing on ice'), findsOneWidget);

      // And it opens the same sheet Android does.
      await tester.tap(find.text('Nothing on ice'));
      await _settle(tester);
      expect(find.text('The usual'), findsOneWidget);
      expect(find.text('Freeze these'), findsOneWidget);
      expect(find.text('Choose apps or sites'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'before Screen Time is allowed, the chip still shows and leads to the setup',
    (tester) async {
      _fakeFreezeChannel(authorized: false);
      await _pumpFocus(tester, const FreezeData());

      expect(find.text('Nothing on ice'), findsOneWidget);
      await tester.tap(find.text('Nothing on ice'));
      await _settle(tester);
      expect(find.text('FREEZE INTRO'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Android shows the same chip in the same state',
    (tester) async {
      _fakeFreezeChannel(authorized: true);
      await _pumpFocus(tester, const FreezeData());
      expect(find.text('Nothing on ice'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    "iOS: the usual's sheet lists the picks as token rows, first six then the rest",
    (tester) async {
      _fakeFreezeChannel(authorized: true);
      await _pumpFocus(
        tester,
        const FreezeData(
          setUp: true,
          recentApps: AppSet(iosSelection: 'sel-usual', iosCount: 8),
        ),
      );

      expect(find.text('The usual'), findsOneWidget);
      expect(find.text('8 on ice'), findsOneWidget);
      await tester.tap(find.text('The usual'));
      await _settle(tester);

      final rows = tester.widgetList<FzListRow>(find.byType(FzListRow)).toList();
      final tokenRows = [
        for (final r in rows)
          if (r.app?.token ?? false) r.app!.id,
      ];
      expect(tokenRows, _tokens.take(6));
      expect(find.text('2 more'), findsOneWidget);
      expect(find.text('8 picked'), findsNothing, reason: 'the icons replace the count');
      // Each row draws its pick (icon and name) through the token view.
      expect(find.byType(FzTokenView), findsNWidgets(12));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    "Android: the usual's sheet lists each package with its icon",
    (tester) async {
      _fakeFreezeChannel(authorized: true);
      await _pumpFocus(
        tester,
        const FreezeData(
          setUp: true,
          recentApps: AppSet(packages: ['com.instagram.android', 'com.google.android.youtube']),
        ),
      );

      await tester.tap(find.text('The usual'));
      await _settle(tester);
      final icons = [for (final i in tester.widgetList<FzAppIcon>(find.byType(FzAppIcon))) i.app.id];
      expect(icons, containsAll(['com.instagram.android', 'com.google.android.youtube']));
      expect(find.text('Instagram'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets("a chip at a large text size doesn't overflow", (tester) async {
    _fakeFreezeChannel(authorized: true);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpFocus(
      tester,
      const FreezeData(setUp: true, recentApps: AppSet(packages: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'])),
    );
    expect(find.text('The usual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without App freeze on this phone there is no chip', (tester) async {
    // An iOS build without the entitlement answers `supported: false`.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(AppFreezeChannel.name),
      (call) async => call.method == 'status' ? {'supported': false} : null,
    );
    await _pumpFocus(tester, const FreezeData());
    expect(find.text('Nothing on ice'), findsNothing);
    expect(find.text('App freeze'), findsNothing);
  });
}
