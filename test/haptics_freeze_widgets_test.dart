// The App freeze controls carry their own feel, once, in fz_widgets.dart:
// chips and segments tick on change and never on the chosen option, the day
// circles leave it to their screen (frost editor, onboarding study hours), and
// an option card plays only the moment its caller opts into.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/freeze/presentation/widgets/fz_widgets.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <(HapticMoment, int)>[];

  List<HapticMoment> get moments => [for (final e in events) e.$1];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add((moment, step));
}

Future<_RecordingHaptics> _pump(WidgetTester tester, Widget child) async {
  final haptics = _RecordingHaptics();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(haptics)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  return haptics;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a chip ticks when picked and is silent when already chosen', (tester) async {
    var taps = 0;
    final haptics = await _pump(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FzChoice(label: 'off', on: false, onTap: () => taps++),
          FzChoice(label: 'on', on: true, onTap: () => taps++),
        ],
      ),
    );

    await tester.tap(find.text('off'));
    await tester.tap(find.text('on'));
    expect(taps, 2, reason: 'both still act');
    expect(haptics.moments, [HapticMoment.chipSelect]);
  });

  testWidgets('a thaw-length chip plays friction with its minutes', (tester) async {
    final haptics = await _pump(
      tester,
      FzChoice(label: '10 min', on: false, haptic: HapticMoment.thawLength, hapticStep: 10, onTap: () {}),
    );

    await tester.tap(find.text('10 min'));
    expect(haptics.events, [(HapticMoment.thawLength, 10)]);
  });

  testWidgets('a segment ticks on change only', (tester) async {
    final haptics = await _pump(
      tester,
      SizedBox(width: 300, child: FzSeg(options: const ['A', 'B'], index: 0, onChanged: (_) {})),
    );

    await tester.tap(find.text('A'));
    expect(haptics.moments, isEmpty, reason: 're-tapping the chosen side is silent');
    await tester.tap(find.text('B'));
    expect(haptics.moments, [HapticMoment.chipSelect]);
  });

  testWidgets('an option card plays the moment it is given, never when chosen', (tester) async {
    final haptics = await _pump(
      tester,
      SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FzPick(icon: 'shield', label: 'Standard', sub: '', selected: true, haptic: HapticMoment.resistancePick, onTap: () {}),
            FzPick(icon: 'trend', label: 'Increasing', sub: '', selected: false, haptic: HapticMoment.resistancePick, onTap: () {}),
            FzPick(icon: 'today', label: 'Silent', sub: '', selected: false, onTap: () {}),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Standard'));
    await tester.tap(find.text('Increasing'));
    await tester.tap(find.text('Silent'));
    expect(haptics.moments, [HapticMoment.resistancePick]);
  });

  testWidgets('day circles are silent by themselves (callers play their own)', (tester) async {
    final haptics = await _pump(
      tester,
      SizedBox(width: 360, child: FzDayPicker(days: const {}, label: '', onChanged: (_) {})),
    );

    await tester.tap(find.text('F'));
    expect(haptics.moments, isEmpty);
  });
}
