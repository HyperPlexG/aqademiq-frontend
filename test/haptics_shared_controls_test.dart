// Shared controls carry their own feel (haptics §4, "Across the app"): a
// toggle latches on and unlatches off, and a chip ticks only when the pick
// changes. Fired from the widget, so every screen using them gets it.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/widgets/app_toggle.dart';
import 'package:aqademiq/shared/widgets/tag_chip.dart';
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

class _Toggle extends StatefulWidget {
  const _Toggle();

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> {
  bool _on = false;

  @override
  Widget build(BuildContext context) => AppToggle(value: _on, onChanged: (v) => setState(() => _on = v));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a toggle latches on and unlatches off', (tester) async {
    final haptics = await _pump(tester, const _Toggle());
    expect(haptics.events, isEmpty, reason: 'building a toggle is silent');

    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    expect(haptics.events, [HapticMoment.toggleOn]);

    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    expect(haptics.events, [HapticMoment.toggleOn, HapticMoment.toggleOff]);
  });

  testWidgets('a disabled toggle is silent', (tester) async {
    final haptics = await _pump(tester, const AppToggle(value: true));
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    expect(haptics.events, isEmpty);
  });

  testWidgets('picking a different chip ticks; the picked one and "+ New" do not', (tester) async {
    var taps = 0;
    final haptics = await _pump(
      tester,
      Wrap(
        children: [
          TagChip(label: 'Exam', active: true, onTap: () => taps++),
          TagChip(label: 'Reading', onTap: () => taps++),
          TagChip(label: '+ New', dashed: true, onTap: () => taps++),
        ],
      ),
    );

    await tester.tap(find.text('Reading'));
    expect(haptics.events, [HapticMoment.chipSelect]);

    await tester.tap(find.text('Exam'));
    await tester.tap(find.text('+ New'));
    expect(haptics.events, [HapticMoment.chipSelect], reason: 'not a change of pick');
    expect(taps, 3, reason: 'every tap still reaches the screen');
  });
}
