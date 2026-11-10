// The "New subject" sheet with the keyboard up, on a small phone. It used to
// grow to its full height plus the keyboard and ride up under the status bar,
// header and Save colliding with the clock. It now stays below the safe area,
// keeps its header pinned and scrolls the body in the height that is left.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/subjects/presentation/widgets/subject_form_sheet.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _dpr = 2.0;

Future<void> _open(
  WidgetTester tester, {
  required Size size,
  required double statusBar,
  required double homeIndicator,
  required double keyboard,
}) async {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = size * _dpr;
  tester.view.padding = FakeViewPadding(top: statusBar * _dpr, bottom: homeIndicator * _dpr);
  tester.view.viewPadding = FakeViewPadding(top: statusBar * _dpr, bottom: homeIndicator * _dpr);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * _dpr);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [hapticsProvider.overrideWithValue(const NoopHapticsService())],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showSubjectFormSheet(context),
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
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // iPhone SE (375×667, 20 status bar, 216+44 keyboard), a small Android phone
  // (360×640, 24 status bar, 280 keyboard) and a notched iPhone mini.
  final phones = <String, ({Size size, double top, double bottom, double keyboard})>{
    'iPhone SE': (size: const Size(375, 667), top: 20, bottom: 0, keyboard: 260),
    'small Android': (size: const Size(360, 640), top: 24, bottom: 0, keyboard: 280),
    'iPhone 13 mini': (size: const Size(375, 812), top: 50, bottom: 34, keyboard: 336),
  };

  for (final MapEntry(key: name, value: phone) in phones.entries) {
    testWidgets('$name: header and Save stay below the status bar with the keyboard up', (tester) async {
      await _open(
        tester,
        size: phone.size,
        statusBar: phone.top,
        homeIndicator: phone.bottom,
        keyboard: phone.keyboard,
      );

      expect(tester.takeException(), isNull);
      final title = find.text('New subject');
      final save = find.text('Save');
      expect(title, findsOneWidget);
      expect(save, findsOneWidget);

      // Below the status bar, not under it.
      expect(tester.getTopLeft(title).dy, greaterThan(phone.top + SubjectFormSheet.topGap));
      expect(tester.getTopLeft(save).dy, greaterThan(phone.top + SubjectFormSheet.topGap));
      // And above the keyboard, so it can be tapped.
      final keyboardTop = phone.size.height - phone.keyboard;
      expect(tester.getBottomLeft(save).dy, lessThan(keyboardTop));
      expect(save.hitTestable(), findsOneWidget);

      // The body scrolls inside what is left: the last row is reachable.
      final mood = find.text('HOW DO YOU FEEL ABOUT IT?', findRichText: true);
      await tester.scrollUntilVisible(mood, 80, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(mood).dy, lessThan(keyboardTop));
      // Scrolling the body never moves the header.
      expect(tester.getTopLeft(title).dy, greaterThan(phone.top + SubjectFormSheet.topGap));
      expect(save.hitTestable(), findsOneWidget);
    });
  }

  testWidgets('without the keyboard the sheet sits at the bottom, not stretched to the top', (tester) async {
    await _open(tester, size: const Size(390, 844), statusBar: 47, homeIndicator: 34, keyboard: 0);

    expect(tester.takeException(), isNull);
    // The whole form fits on a tall phone: the sheet is its own height, so its
    // header is well below the status bar.
    expect(tester.getTopLeft(find.text('New subject')).dy, greaterThan(47 + 40));
    expect(find.text('HOW DO YOU FEEL ABOUT IT?', findRichText: true).hitTestable(), findsOneWidget);
  });
}
