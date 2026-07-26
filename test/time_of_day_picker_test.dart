import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/plan/presentation/pickers/time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opens the picker with [current] and returns once the sheet is on screen.
Future<void> _openWith(WidgetTester tester, {String? current}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showTimeOfDayPicker(ctx, current: current),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The row (GestureDetector) that wraps a given option label.
Finder _rowOf(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(GestureDetector)).first;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Time-of-day picker — reflects the current selection', () {
    // The reported bug: pick Afternoon, reopen, and it showed Anytime checked.
    testWidgets('highlights the passed value, not Anytime', (tester) async {
      await _openWith(tester, current: 'Afternoon');

      expect(
        find.descendant(of: _rowOf('Afternoon'), matching: find.byIcon(Icons.check)),
        findsOneWidget,
        reason: 'the previously-chosen bucket must be checked',
      );
      expect(
        find.descendant(of: _rowOf('Anytime'), matching: find.byIcon(Icons.check)),
        findsNothing,
        reason: 'Anytime must not be checked when Afternoon is selected',
      );
    });

    testWidgets('defaults to Anytime when nothing is passed', (tester) async {
      await _openWith(tester);

      expect(
        find.descendant(of: _rowOf('Anytime'), matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _rowOf('Afternoon'), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('a specific time highlights the Specific time row', (tester) async {
      await _openWith(tester, current: '2:30 PM');

      // The set time shows in the trailing pill.
      expect(find.text('2:30 PM'), findsOneWidget);
      // No bucket is checked.
      expect(
        find.descendant(of: _rowOf('Anytime'), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });
  });
}
