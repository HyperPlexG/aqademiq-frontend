// Regression guard for the App Review failure on submission 7d5244b9
// (iPad Air 11-inch, iPadOS 26.6): "the app became unresponsive when tapping
// anywhere".
//
// The sign-in screen gates every primary control on one flag —
// `authControllerProvider.isLoading`. That is fine as long as the flag always
// clears, but a native SSO sheet that cannot present never calls back, so the
// flag stuck true and Apple / Google / Sign in all became `null` handlers at
// once. With no back button on the screen, there was nothing left to tap.
//
// Two independent properties keep that from being fatal again, and each is
// asserted below:
//
//   1. There is always a way off this screen, whatever else breaks.
//   2. An SSO button is only offered when it can actually work.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/auth/presentation/signin_screen.dart';
import 'package:aqademiq/shared/widgets/circle_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _pumpSignin(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      // The real theme, not a bare MaterialApp: the design tokens travel as a
      // theme extension and `context.colors` throws without them.
      child: MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AppAccent.violet,
        ),
        home: const SigninScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('sign-in always offers a way back', (tester) async {
    await _pumpSignin(tester);

    // Sign-up and OTP both had one; sign-in did not, which is what turned a
    // failed SSO call into a dead end rather than an annoyance.
    expect(
      find.byType(CircleBackButton),
      findsOneWidget,
      reason: 'Sign-in must have an escape hatch — every other control on this '
          'screen can be disabled at once by the busy flag.',
    );
  });

  testWidgets('Google sign-in is not offered when it cannot work', (tester) async {
    await _pumpSignin(tester);

    // No dart-defines under test, so no client ids are configured. Offering the
    // button here is worse than hiding it: the SDK cannot present its sheet and
    // never calls back, which is precisely how the screen wedged.
    expect(
      find.text('Sign in with Google'),
      findsNothing,
      reason: 'An SSO button with no client id configured can only hang.',
    );
  });

  testWidgets('the email path stays usable', (tester) async {
    await _pumpSignin(tester);

    // Guards the fix from over-correcting: hiding a broken SSO button must not
    // take the working sign-in path with it.
    expect(find.text('Sign in →'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
