// Thaw · a breath first: the breath is held for as long as the wait is on
// screen. It runs to its end with the wait, and fades out (cancel) when the
// student leaves early. Stepping the length plays friction with the minutes.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/freeze/presentation/freeze_apps.dart';
import 'package:aqademiq/features/freeze/presentation/thaw_screen.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _Hold implements HapticHold {
  String? ended;

  @override
  void cancel({Duration fade = const Duration(milliseconds: 150)}) => ended ??= 'cancel';

  @override
  void finish() => ended ??= 'finish';
}

class _RecordingHaptics extends NoopHapticsService {
  final events = <(HapticMoment, int)>[];
  final holds = <(HapticMoment, _Hold)>[];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add((moment, step));

  @override
  HapticHold hold(HapticMoment moment) {
    final h = _Hold();
    holds.add((moment, h));
    return h;
  }
}

Future<_RecordingHaptics> _pumpThaw(WidgetTester tester) async {
  final haptics = _RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(haptics),
        freezeAppsProvider.overrideWithValue(const FreezeApps(ios: false, labels: {}, floor: {})),
      ],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ThawScreen(request: ThawRequest(target: 'com.example.app', label: 'Example')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // The ice timer animates for ever, so pump the route in rather than settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return haptics;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the 10 s breath runs with the wait and finishes with it', (tester) async {
    final haptics = await _pumpThaw(tester);
    expect(haptics.holds.map((h) => h.$1), [HapticMoment.thawBreath]);
    final hold = haptics.holds.single.$2;
    expect(hold.ended, isNull);

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(hold.ended, 'finish');
  });

  testWidgets('leaving the wait early fades the breath out', (tester) async {
    final haptics = await _pumpThaw(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Keep it frozen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(haptics.holds.single.$2.ended, 'cancel');
  });

  testWidgets('stepping the thaw length plays friction with the minutes', (tester) async {
    final haptics = await _pumpThaw(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.text('Thaw'));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pump();
    await tester.tap(find.text('15 min'));
    await tester.pump();
    await tester.tap(find.text('15 min'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pump();
    expect(haptics.events, [(HapticMoment.thawLength, 5), (HapticMoment.thawLength, 15)],
        reason: 'the chosen chip and a step past the end are silent');
  });
}
