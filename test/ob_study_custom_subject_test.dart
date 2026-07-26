import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_study_screen.dart';
import 'package:aqademiq/features/onboarding/providers/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Serves a fixed onboarding draft so the study screen renders a known set of
/// selected subjects.
class _FixedOnboarding extends OnboardingController {
  _FixedOnboarding(this._draft);
  final OnboardingDraft _draft;

  @override
  OnboardingDraft build() => _draft;
}

Future<void> _pump(WidgetTester tester, OnboardingDraft draft) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [onboardingProvider.overrideWith(() => _FixedOnboarding(draft))],
      child: MaterialApp(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        home: const ObStudyScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ObStudyScreen — custom subjects', () {
    // The reported bug: adding a subject via "+ More" put it in the draft but
    // no chip appeared, because the row only rendered the preset list.
    testWidgets('a custom subject in the draft shows as a chip', (tester) async {
      await _pump(
        tester,
        const OnboardingDraft(subjects: ['Physics']),
      );

      expect(find.text('Physics'), findsOneWidget);
      // Presets and the add affordance are still there.
      expect(find.text('Engineering'), findsOneWidget);
      expect(find.text('+ More'), findsOneWidget);
    });

    testWidgets('no duplicate chip when the added subject is a preset',
        (tester) async {
      await _pump(
        tester,
        const OnboardingDraft(subjects: ['CS']),
      );

      // 'CS' is a preset; selecting it must not render a second chip.
      expect(find.text('CS'), findsOneWidget);
    });

    testWidgets('with no custom subjects, only the presets render',
        (tester) async {
      await _pump(tester, const OnboardingDraft());

      for (final preset in ['Engineering', 'CS', 'Medicine', 'Business', 'Law']) {
        expect(find.text(preset), findsOneWidget);
      }
      expect(find.text('+ More'), findsOneWidget);
    });
  });
}
