// Settings must never offer a guest "Sign out".
//
// This is a data-loss guard, not a cosmetic one. A guest IS their anonymous
// Supabase session — there are no credentials to sign back in with. Signing out
// does not log them out of anything; it abandons the only handle on their tasks,
// subjects and streaks, permanently, with no warning and no way back. The row
// shipped to every guest for months.
//
// The positive half matters too: the offer to keep that data has to be present,
// or the guest has no route to an account from Settings at all.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/data/auth/auth_repository.dart';
import 'package:aqademiq/features/settings/presentation/settings_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _pumpSettings(WidgetTester tester, {required bool guest}) async {
  // A tall surface so the whole settings list builds. Account sits well below
  // the fold, and a lazily-built list would report it "not found" on a phone-
  // sized viewport whether the fix worked or not.
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [isGuestProvider.overrideWithValue(guest)],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const SettingsHomeScreen(),
      ),
    ),
  );
  // Explicit pumps rather than pumpAndSettle: the mock sources schedule delayed
  // futures that outlive the tree, and pumpAndSettle asserts on the leftover
  // timer instead of reporting what the screen actually rendered.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a guest is never shown Sign out', (tester) async {
    await _pumpSettings(tester, guest: true);
    expect(
      find.text('Sign out'),
      findsNothing,
      reason: 'signing out destroys an anonymous account and everything in it',
    );
  });

  testWidgets('a guest is offered a way to keep their progress', (tester) async {
    await _pumpSettings(tester, guest: true);
    expect(find.text('Create account & save progress'), findsOneWidget);
  });

  testWidgets('a guest is not shown account rows that cannot apply', (tester) async {
    // No email exists to configure, and there is no account to delete.
    await _pumpSettings(tester, guest: true);
    expect(find.text('Email settings'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
  });

  testWidgets('a signed-in user still gets the real account rows', (tester) async {
    // The guard must not have cost signed-in users their own settings.
    await _pumpSettings(tester, guest: false);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Create account & save progress'), findsNothing);
  });
}
