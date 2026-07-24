import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/features/focus/presentation/focus_end_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Serves a fixed session so the end screen renders a known elapsed time.
class _FixedFocusController extends FocusController {
  _FixedFocusController(this._session);
  final FocusSession _session;

  @override
  FocusSession build() => _session;
}

Future<void> _pumpEnd(WidgetTester tester, FocusSession session) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        focusControllerProvider.overrideWith(() => _FixedFocusController(session)),
      ],
      child: const MaterialApp(home: FocusEndScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Focus end screen — Focused time', () {
    // The reported bug: a 30-minute session ended after 20 seconds showed
    // "30:00". It must show the time actually focused.
    testWidgets('shows elapsed time, not the planned duration', (tester) async {
      await _pumpEnd(
        tester,
        const FocusSession(id: 's', durationMin: 30, elapsedSec: 20),
      );

      expect(find.text('00:20'), findsOneWidget);
      expect(find.text('30:00'), findsNothing);
    });

    testWidgets('a full session still reads its whole duration', (tester) async {
      await _pumpEnd(
        tester,
        const FocusSession(id: 's', durationMin: 30, elapsedSec: 1800),
      );

      expect(find.text('30:00'), findsOneWidget);
    });

    testWidgets('formats minutes and seconds with leading zeros', (tester) async {
      await _pumpEnd(
        tester,
        const FocusSession(id: 's', durationMin: 25, elapsedSec: 65),
      );

      expect(find.text('01:05'), findsOneWidget);
    });
  });
}
