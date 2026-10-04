import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/shared/mascot/ada_mascot.dart';
import 'package:aqademiq/shared/mascot/ice_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// The in-app half of the material rule the ambient surfaces already keep:
/// melting is time being spent, frost is time held.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<AdaMascot> ada(WidgetTester tester, {required bool frost}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AppAccent.violet,
        ),
        home: Center(child: IceTimer(progress: 0.8, frost: frost)),
      ),
    );
    // Past the 900ms melt tween. Not pumpAndSettle: the breathing and the
    // shimmer loop forever by design.
    await tester.pump(const Duration(seconds: 1));
    return tester.widget<AdaMascot>(find.byType(AdaMascot));
  }

  testWidgets('a running session melts Ada and does not frost her', (
    tester,
  ) async {
    final mascot = await ada(tester, frost: false);
    expect(mascot.frozen, isFalse);
    expect(mascot.melt, closeTo(0.8, 0.001));
  });

  // She used to stay purple and melting on a frozen session — the one place
  // that disagreed with the lock screen, the Island and the watch.
  testWidgets('a frozen session turns Ada to frost', (tester) async {
    final mascot = await ada(tester, frost: true);
    expect(mascot.frozen, isTrue);
  });

  // The frozen look used to pin melt at 0.4: frozen at 80% she un-melted, and
  // frozen at 10% she suddenly lost a third of herself.
  testWidgets('a freeze holds the melt she had, it does not reset it', (
    tester,
  ) async {
    final mascot = await ada(tester, frost: true);
    expect(mascot.melt, closeTo(0.8, 0.001));
  });
}
