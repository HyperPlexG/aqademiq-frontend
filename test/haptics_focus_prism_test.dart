// Prism picker: highlighting a mode plays that mode's Prism pattern; the mode
// already chosen changes nothing and stays silent.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/focus/presentation/sheets/prism_picker.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/widgets/ic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <(HapticMoment, String?)>[];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add((moment, mode));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<(_RecordingHaptics, List<String?>)> pumpPicker(WidgetTester tester) async {
    final haptics = _RecordingHaptics();
    final results = <String?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsProvider.overrideWithValue(haptics)],
        child: MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => results.add(await showPrismPicker(context, current: 'Deep Work')),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (haptics, results);
  }

  testWidgets('picking a mode plays its pattern', (tester) async {
    final (haptics, results) = await pumpPicker(tester);
    await tester.tap(find.text('Flow'));
    await tester.pumpAndSettle();
    expect(results, ['Flow']);
    expect(haptics.events, [(HapticMoment.prismPicked, 'Flow')]);
  });

  testWidgets('the active mode is silent', (tester) async {
    final (haptics, results) = await pumpPicker(tester);
    await tester.tap(find.text('Deep Work'));
    await tester.pumpAndSettle();
    expect(results, ['Deep Work']);
    expect(haptics.events, isEmpty);
  });

  // v11 fc-prism: each mode is the pack's state mark in the mode colour (the
  // same marks as Meet Prism), and the footer reads just "Autoplay".
  testWidgets("the picker draws the design's marks and says Autoplay", (tester) async {
    await pumpPicker(tester);
    final names = [for (final ic in tester.widgetList<Ic>(find.byType(Ic))) ic.name];
    expect(names, containsAllInOrder(['state_deep_focus', 'state_focus', 'state_creative', 'state_relax', 'mute', 'prism']));
    expect(find.text('Autoplay'), findsOneWidget);
    expect(find.text('Autoplay Prism'), findsNothing);
  });
}
