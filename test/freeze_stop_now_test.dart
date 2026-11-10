// "Until I stop" has a stop: the hub's Stop freezing goes through the same
// breath as a thaw, then ends the Freeze now for good, with no "how long"
// step after it.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/freeze/domain/freeze_models.dart';
import 'package:aqademiq/features/freeze/presentation/freeze_apps.dart';
import 'package:aqademiq/features/freeze/presentation/thaw_screen.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _UntimedFreeze extends FreezeController {
  bool stopped = false;

  @override
  FreezeData build() => FreezeData(now: FreezeNow(startedAt: DateTime(2026, 11, 10, 9)));

  @override
  void stopNow() {
    stopped = true;
    state = state.copyWith(clearNow: true);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Stop freezing ends an untimed Freeze now after the breath', (tester) async {
    final controller = _UntimedFreeze();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsProvider.overrideWithValue(const NoopHapticsService()),
          freezeAppsProvider.overrideWithValue(const FreezeApps(ios: false, labels: {}, floor: {})),
          freezeControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ThawScreen(request: ThawRequest(target: ThawGrant.allApps, stopNow: true)),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Still want to stop freezing'), findsOneWidget);
    expect(find.text('Stop freezing'), findsNothing, reason: 'not before the breath');

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('Stop freezing'), findsOneWidget);
    await tester.tap(find.text('Stop freezing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.stopped, isTrue);
    expect(find.text('Thaw for 2 min'), findsNothing, reason: 'no how-long step');
    expect(find.text('open'), findsOneWidget, reason: 'the breath closed');
  });
}
