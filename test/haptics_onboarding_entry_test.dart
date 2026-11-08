// Entry and onboarding touchpoints (haptic architecture §4, "00 · Entry and
// 01 · Onboarding"): consent latches on agree only, the referral code ticks
// per character with the 4th at index 3, a miss knocks, and each melt cube
// plays its own texture.

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_consent_screen.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_mood_screen.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_referral_screen.dart';
import 'package:aqademiq/features/onboarding/providers/onboarding_controller.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/widgets/mood_blob.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _RecordingHaptics extends NoopHapticsService {
  final events = <(HapticMoment, int)>[];

  List<HapticMoment> get moments => [for (final e in events) e.$1];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add((moment, step));
}

Future<(_RecordingHaptics, ProviderContainer)> _pump(WidgetTester tester, Widget screen) async {
  final haptics = _RecordingHaptics();
  final container = ProviderContainer(overrides: [hapticsProvider.overrideWithValue(haptics)]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: screen,
      ),
    ),
  );
  await tester.pump();
  return (haptics, container);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('consent: agree latches, decline is silent', (tester) async {
    final (haptics, _) = await _pump(tester, const ObConsentScreen());

    await tester.tap(find.text("No, I don't consent"));
    await tester.pump();
    expect(haptics.moments, isEmpty, reason: 'declining is not marked');

    await tester.tap(find.text('Yes, I consent'));
    await tester.pump();
    expect(haptics.moments, [HapticMoment.consentAgree]);

    await tester.tap(find.text('Yes, I consent'));
    await tester.pump();
    expect(haptics.moments, [HapticMoment.consentAgree], reason: 'already agreed: nothing changed');
  });

  testWidgets('referral: a tick per character, none on delete, a knock on a miss', (tester) async {
    final (haptics, _) = await _pump(tester, const ObReferralScreen());
    final field = find.byType(TextField);

    const code = 'ABCDEFGH';
    for (var i = 1; i <= code.length; i++) {
      await tester.enterText(field, code.substring(0, i));
      await tester.pump();
    }
    expect(haptics.events, [for (var i = 0; i < 8; i++) (HapticMoment.referralChar, i)]);

    await tester.enterText(field, code.substring(0, 7));
    await tester.pump();
    expect(haptics.events, hasLength(8), reason: 'deleting is silent');

    await tester.enterText(field, code);
    await tester.pump();
    expect(haptics.events.last, (HapticMoment.referralChar, 7));

    // Mock mode answers an unknown code with a 422.
    haptics.events.clear();
    await tester.tap(find.text('Continue →'));
    await tester.pumpAndSettle();
    expect(haptics.moments, [HapticMoment.referralNotFound]);
  });

  testWidgets('feelings per subject: each cube plays its texture step', (tester) async {
    final (haptics, container) = await _pump(tester, const ObMoodScreen());
    container.read(onboardingProvider.notifier).toggleSubject('CS');
    await tester.pump();

    final cubes = find.byType(MoodBlob);
    expect(cubes, findsNWidgets(5));

    await tester.tap(cubes.at(2));
    await tester.pump();
    expect(haptics.events, isEmpty, reason: 'the middle cube is already picked');

    await tester.tap(cubes.at(0));
    await tester.pump();
    await tester.tap(cubes.at(4));
    await tester.pump();
    expect(haptics.events, [(HapticMoment.feelingPick, 0), (HapticMoment.feelingPick, 4)]);
  });
}
