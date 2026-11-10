// "Rate Aqademiq" goes to the store's rating page — the only place a rating
// does anything. It replaced an in-app star sheet whose ratings never left our
// own database.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/settings/rate_app.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <HapticMoment>[];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add(moment);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('storeReviewUris', () {
    test('iOS goes to the App Store write-a-review page for our id', () {
      expect(storeReviewUris(TargetPlatform.iOS).map((u) => '$u'), [
        'https://apps.apple.com/app/id6792360288?action=write-review',
      ]);
    });

    test('Android tries the Play Store app, then the Play listing on the web', () {
      expect(storeReviewUris(TargetPlatform.android).map((u) => '$u'), [
        'market://details?id=com.r13.aqademiq',
        'https://play.google.com/store/apps/details?id=com.r13.aqademiq',
      ]);
    });

    test('a platform with no store gets nothing to open', () {
      expect(storeReviewUris(TargetPlatform.linux), isEmpty);
      expect(storeReviewUris(TargetPlatform.windows), isEmpty);
    });
  });

  group('rateApp', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<(_RecordingHaptics, List<Uri>)> tapRate(
      WidgetTester tester, {
      required bool Function(Uri) opens,
    }) async {
      final haptics = _RecordingHaptics();
      final tried = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hapticsProvider.overrideWithValue(haptics),
            storeOpenerProvider.overrideWithValue((uri) async {
              tried.add(uri);
              return opens(uri);
            }),
          ],
          child: MaterialApp(
            theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => rateApp(context),
                  child: const Text('Rate Aqademiq'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rate Aqademiq'));
      await tester.pumpAndSettle();
      return (haptics, tried);
    }

    testWidgets('iOS: one tap opens the App Store review page, no sheet', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final (haptics, tried) = await tapRate(tester, opens: (_) => true);
      expect(tried.map((u) => '$u'), ['https://apps.apple.com/app/id6792360288?action=write-review']);
      expect(haptics.events, [HapticMoment.rateSubmit]);
      expect(find.text('Submit rating'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android without the Play Store falls back to the web listing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final (_, tried) = await tapRate(tester, opens: (u) => u.scheme == 'https');
      expect(tried.map((u) => u.scheme), ['market', 'https']);
      expect(find.byType(SnackBar), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('nothing can open the store: say so instead of doing nothing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final (_, tried) = await tapRate(tester, opens: (_) => false);
      expect(tried, hasLength(2));
      expect(find.text("Couldn't open the store. Please try again."), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
