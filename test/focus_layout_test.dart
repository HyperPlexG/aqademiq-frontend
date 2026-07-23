import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/focus/presentation/timer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The Focus screen used to be a top-packed Column, so the timer cluster bunched
/// under the header pills and left the lower half of the screen empty. These
/// tests pin the corrected behaviour: the cluster centres in the frame, and
/// falls back to scrolling rather than overflowing when the frame is short.
Future<void> _pumpFocus(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AppAccent.violet,
        ),
        home: const Scaffold(body: TimerScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 950));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Focus screen layout', () {
    testWidgets('timer cluster is centred, not packed against the top',
        (tester) async {
      const size = Size(390, 844);
      await _pumpFocus(tester, size);

      final title = tester.getRect(find.text('Focus'));
      final start = tester.getRect(find.text('Start focus'));

      // The cluster spans the middle of the frame. Before the fix the whole
      // group finished in the top ~55%, leaving the rest blank.
      final clusterCentre = (title.top + start.bottom) / 2;
      expect(
        clusterCentre,
        greaterThan(size.height * 0.30),
        reason: 'cluster should not hug the top of the frame',
      );
      expect(
        clusterCentre,
        lessThan(size.height * 0.70),
        reason: 'cluster should sit around the middle of the frame',
      );
    });

    testWidgets('header pills stay pinned at the top', (tester) async {
      await _pumpFocus(tester, const Size(390, 844));

      final pill = tester.getRect(find.text('Prism'));
      final title = tester.getRect(find.text('Focus'));

      expect(pill.top, lessThan(100), reason: 'pills belong at the top');
      expect(
        pill.bottom,
        lessThan(title.top),
        reason: 'pills sit above the centred cluster',
      );
    });

    testWidgets('does not overflow on a short screen', (tester) async {
      // iPhone SE class height — the cluster is taller than the frame here, so
      // this is the case a fixed Column would have thrown a RenderFlex overflow.
      await _pumpFocus(tester, const Size(320, 480));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('does not overflow at a large text scale', (tester) async {
      await _pumpFocus(tester, const Size(390, 844));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
