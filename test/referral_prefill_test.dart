// A referral link fills the onboarding field, and never does more than that.
//
// `referral_link_test.dart` covers what a link means; this covers what the app
// does with one. The two halves that matter are both about restraint: the code
// has to actually arrive (or the whole feature is decorative), and it must not
// arrive in a way the student cannot undo.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/auth/presentation/widgets/otp_field.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_referral_screen.dart';
import 'package:aqademiq/features/onboarding/providers/onboarding_controller.dart';
import 'package:aqademiq/services/deep_link_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _code = 'A1B2C3D4';

/// A service with a code already captured, without touching a platform channel.
DeepLinkService _serviceWith(String? code) {
  final s = DeepLinkService()..pendingReferralCode = code;
  return s;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  String? pendingCode,
  String alreadyTyped = '',
}) async {
  final container = ProviderContainer(
    overrides: [
      deepLinkServiceProvider.overrideWithValue(_serviceWith(pendingCode)),
    ],
  );
  addTearDown(container.dispose);
  if (alreadyTyped.isNotEmpty) {
    container.read(onboardingProvider.notifier).setReferral(alreadyTyped);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(
          brightness: Brightness.light,
          accent: AppAccent.violet,
        ),
        home: const ObReferralScreen(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

String _fieldValue(WidgetTester tester) =>
    tester.widget<OtpField>(find.byType(OtpField)).initial;

void main() {
  testWidgets('a code from a link lands in the field', (tester) async {
    // Without this the feature is decorative: the link opens the app and the
    // student still types eight hex characters by hand.
    final container = await _pump(tester, pendingCode: _code);
    expect(_fieldValue(tester), _code);
    // And it reaches the draft that gets submitted at the end of the wizard.
    expect(container.read(onboardingProvider).referral, _code);
  });

  testWidgets('no link means an empty field, not a stale one', (tester) async {
    await _pump(tester);
    expect(_fieldValue(tester), '');
  });

  testWidgets('a link never overwrites something already typed', (
    tester,
  ) async {
    // Someone part-way through entering a friend's code must not have it
    // silently swapped by a link that arrived in the background.
    final container = await _pump(
      tester,
      pendingCode: _code,
      alreadyTyped: 'DEADBEEF',
    );
    expect(_fieldValue(tester), 'DEADBEEF');
    expect(container.read(onboardingProvider).referral, 'DEADBEEF');
  });

  testWidgets('the code is consumed, so clearing the field sticks', (
    tester,
  ) async {
    // The reason takeReferralCode empties the slot. If the code were merely
    // read, leaving and returning to the step would put back a code the
    // student had deliberately removed.
    final service = _serviceWith(_code);
    final container = ProviderContainer(
      overrides: [deepLinkServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(
            brightness: Brightness.light,
            accent: AppAccent.violet,
          ),
          home: const ObReferralScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(
      service.pendingReferralCode,
      isNull,
      reason: 'the code was not consumed',
    );

    // The student clears it, then comes back to the step.
    container.read(onboardingProvider.notifier).setReferral('');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildAppTheme(
            brightness: Brightness.light,
            accent: AppAccent.violet,
          ),
          home: const ObReferralScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(container.read(onboardingProvider).referral, '');
  });

  testWidgets('a link does not submit anything by itself', (tester) async {
    // Prefill, never act. The step still has to be confirmed, and nothing is
    // redeemed until POST /onboarding/complete at the end of the wizard.
    await _pump(tester, pendingCode: _code);
    expect(tester.takeException(), isNull);
    // Still on the referral step — no navigation happened on its own.
    expect(find.byType(ObReferralScreen), findsOneWidget);
  });
}
