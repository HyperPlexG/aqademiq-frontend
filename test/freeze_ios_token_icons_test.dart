// iOS hands App freeze opaque tokens, never names, so the hub draws each pick
// through a platform view (`aqademiq/fz_token`) that FamilyControls fills in.
// These tests stand in for the native side: a fake `aqademiq/app_freeze`
// answers `selectionTokens`, and `flutter/platform_views` records what the
// framework asked iOS to create. Where the tokens can't be drawn, the count
// tile stays.

import 'dart:convert';

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/freeze/data/app_freeze_channel.dart';
import 'package:aqademiq/features/freeze/data/freeze_store.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/presentation/freeze_hub_screen.dart';
import 'package:aqademiq/features/freeze/presentation/widgets/fz_widgets.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Eight picks under Freeze now: a category first, as the native side
/// orders them, then apps.
const _nowTokens = ['cat_social', 'app_1', 'app_2', 'app_3', 'app_4', 'app_5', 'app_6', 'app_7'];
const _distractingTokens = ['app_d1', 'app_d2'];

/// A running Freeze now over an iOS selection, and a Distracting group.
FreezeData _data() {
  final started = DateTime.now().subtract(const Duration(minutes: 5));
  return FreezeData.fromJson({
    'v': 1,
    'set_up': true,
    'now': {
      'started_at': started.millisecondsSinceEpoch,
      'deep': false,
      'with_focus': false,
      'apps': {'packages': <String>[], 'ios_selection': 'sel-now', 'ios_count': _nowTokens.length, 'mode': 'freezeThese'},
    },
    'groups': {
      'distracting': {
        'packages': <String>[],
        'ios_selection': 'sel-distracting',
        'ios_count': _distractingTokens.length,
        'mode': 'freezeThese',
      },
    },
  });
}

/// The fake native side. [tokens] is what `selectionTokens` answers per
/// selection; null for a selection means "can't draw tokens here".
void _fakeFreezeChannel(Map<String, List<String>?> tokens) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel(AppFreezeChannel.name),
    (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const <Object?, Object?>{};
      return switch (call.method) {
        'status' => {'supported': true, 'authorized': true, 'usage_access': true, 'overlay': true, 'notifications': true},
        'selectionTokens' => tokens[args['selection_id']],
        _ => null,
      };
    },
  );
}

/// Records the platform views the framework creates, by their `id` param.
List<Map<Object?, Object?>> _recordPlatformViews() {
  final created = <Map<Object?, Object?>>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform_views,
    (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final params = args['params'] as Uint8List?;
        created.add({
          'viewType': args['viewType'],
          ...?(params == null
              ? null
              : const StandardMessageCodec().decodeMessage(ByteData.sublistView(params)) as Map<Object?, Object?>?),
        });
      }
      return null;
    },
  );
  return created;
}

Future<void> _pumpHub(WidgetTester tester) async {
  await FreezeStore.instance.write(_data());
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(const NoopHapticsService())],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const FreezeHubScreen(),
      ),
    ),
  );
  // The token ids arrive over the channel.
  await tester.pump();
  await tester.pump();
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
    'iOS draws each pick through the token view, first six then "+N"',
    (tester) async {
      _fakeFreezeChannel({'sel-now': _nowTokens, 'sel-distracting': _distractingTokens});
      final created = _recordPlatformViews();
      await _pumpHub(tester);

      // The Frozen row: a tile per pick, capped, then the rest as "+2".
      final tiles = tester.widgetList<FzAppTile>(find.byType(FzAppTile)).toList();
      expect([for (final t in tiles) t.app.id], _nowTokens.take(6));
      expect(tiles.every((t) => t.app.token && t.state == FzTileState.frozen), isTrue);
      expect(find.byType(FzMoreTile), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.byType(FzCountTile), findsNothing, reason: 'the icons replace the count');

      // The Distracting group's cells draw its two picks too.
      final ids = [for (final v in tester.widgetList<FzTokenView>(find.byType(FzTokenView))) v.id];
      expect(ids, containsAll([..._nowTokens.take(6), ..._distractingTokens]));
      expect(ids, isNot(contains('app_7')), reason: 'past the cap is "+N", not another view');

      // And each became one iOS platform view of ours, asked for by id.
      expect(find.byType(UiKitView), findsNWidgets(ids.length));
      await tester.pump();
      expect(created, isNotEmpty);
      expect(created.every((c) => c['viewType'] == FzTokenView.viewType && c['style'] == 'icon'), isTrue);
      expect({for (final c in created) c['id']}, containsAll(['cat_social', 'app_1', 'app_d1']));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    "iOS keeps the count tile where tokens can't be drawn",
    (tester) async {
      // `selectionTokens` answers null: below iOS 16, or no entitlement.
      _fakeFreezeChannel({});
      final created = _recordPlatformViews();
      await _pumpHub(tester);

      expect(find.byType(FzCountTile), findsOneWidget);
      expect(find.text('8 apps'), findsOneWidget);
      expect(find.byType(FzAppTile), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(created, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('a token view off iOS draws nothing and leaves the placeholder', (tester) async {
    expect(defaultTargetPlatform, isNot(TargetPlatform.iOS));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const Center(child: ProviderScope(child: FzAppIcon(app: FzAppRef.token('app_1'), size: 60))),
      ),
    );
    expect(find.byType(UiKitView), findsNothing);
    expect(tester.getSize(find.byType(FzAppIcon)), const Size.square(60));
  });

  test('the token ids stay out of the policy the native side stores', () {
    // Only the selection id crosses `applyPolicy`; the ids are asked for
    // separately and never saved by Dart.
    final policy = jsonEncode(AppFreezeChannel.policyOf(_data(), DateTime.now()));
    for (final id in _nowTokens) {
      expect(policy, isNot(contains(id)));
    }
    expect(policy, contains('sel-now'));
  });
}
