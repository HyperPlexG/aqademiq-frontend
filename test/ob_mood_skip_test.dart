// "How do you feel about each?" rates the subjects picked on the study step.
// With none picked it used to show anyway, an empty page with a Continue
// button. It is skipped now, forward and back, and the progress dots close
// up behind it instead of leaving a gap.

import 'package:aqademiq/core/router/app_router.dart';
import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/core/theme/app_theme.dart';
import 'package:aqademiq/features/freeze/providers/freeze_controller.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_hours_screen.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_mood_screen.dart';
import 'package:aqademiq/features/onboarding/presentation/ob_study_screen.dart';
import 'package:aqademiq/features/onboarding/providers/onboarding_controller.dart';
import 'package:aqademiq/features/onboarding/providers/onboarding_steps.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:aqademiq/shared/widgets/onboarding_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _FixedOnboarding extends OnboardingController {
  _FixedOnboarding(this._draft);
  final OnboardingDraft _draft;

  @override
  OnboardingDraft build() => _draft;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<String> subjects,
  bool freeze = true,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.obStudy,
    routes: [
      GoRoute(path: Routes.obStudy, builder: (_, _) => const ObStudyScreen()),
      GoRoute(path: Routes.obMood, builder: (_, _) => const ObMoodScreen()),
      GoRoute(path: Routes.obHours, builder: (_, _) => const ObHoursScreen()),
      GoRoute(path: Routes.obFreeze, builder: (_, _) => const SizedBox()),
      GoRoute(path: Routes.obPrism, builder: (_, _) => const SizedBox()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(const NoopHapticsService()),
        appFreezeAvailableProvider.overrideWithValue(freeze),
        onboardingProvider.overrideWith(() => _FixedOnboarding(OnboardingDraft(subjects: subjects))),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(brightness: Brightness.light, accent: AppAccent.violet),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ObStudyScreen)));
}

OnboardingDots _dots(WidgetTester tester) => tester.widget<OnboardingDots>(find.byType(OnboardingDots).last);

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue →').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('onboardingStepsProvider', () {
    List<ObStep> steps({required bool subjects, required bool freeze}) {
      final container = ProviderContainer(
        overrides: [
          appFreezeAvailableProvider.overrideWithValue(freeze),
          onboardingProvider.overrideWith(
            () => _FixedOnboarding(OnboardingDraft(subjects: subjects ? const ['CS'] : const [])),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(onboardingStepsProvider);
    }

    test('every step when there are subjects and App freeze', () {
      expect(steps(subjects: true, freeze: true), ObStep.values);
    });

    test('no subjects drops the feelings step and nothing else', () {
      final s = steps(subjects: false, freeze: true);
      expect(s, isNot(contains(ObStep.mood)));
      expect(s.length, ObStep.values.length - 1);
    });

    test('a phone without App freeze drops its two steps', () {
      final s = steps(subjects: true, freeze: false);
      expect(s, isNot(contains(ObStep.freeze)));
      expect(s, isNot(contains(ObStep.apps)));
      expect(s.length, ObStep.values.length - 2);
    });
  });

  testWidgets('no subjects: Continue skips the feelings step, Back returns to study', (tester) async {
    await _pump(tester, subjects: const []);
    expect(_dots(tester).active, 5);
    expect(_dots(tester).total, 10);

    await _continue(tester);
    expect(find.byType(ObMoodScreen), findsNothing);
    expect(find.text('How do you feel\nabout each?'), findsNothing);
    expect(find.byType(ObHoursScreen), findsOneWidget);
    // Study hours is the very next dot: no gap where the feelings step was.
    expect(_dots(tester).active, 6);
    expect(_dots(tester).total, 10);

    // Back from study hours goes to the study step, not the skipped one.
    await tester.binding.handlePopRoute(); // the system back (Android) / edge swipe
    await tester.pumpAndSettle();
    expect(find.byType(ObStudyScreen), findsOneWidget);
    expect(find.byType(ObMoodScreen), findsNothing);
  });

  testWidgets('with subjects: the feelings step shows, then study hours', (tester) async {
    await _pump(tester, subjects: const ['CS', 'Law']);
    expect(_dots(tester).total, 11);

    await _continue(tester);
    expect(find.byType(ObMoodScreen), findsOneWidget);
    expect(find.text('CS'), findsOneWidget);
    expect(_dots(tester).active, 6);

    await _continue(tester);
    expect(find.byType(ObHoursScreen), findsOneWidget);
    expect(_dots(tester).active, 7);
    expect(_dots(tester).total, 11);

    // Back walks through the feelings step on the way to study.
    await tester.binding.handlePopRoute(); // the system back (Android) / edge swipe
    await tester.pumpAndSettle();
    expect(find.byType(ObMoodScreen), findsOneWidget);
  });

  testWidgets('picking then unpicking every subject skips the step again', (tester) async {
    final container = await _pump(tester, subjects: const []);
    await tester.tap(find.text('CS'));
    await tester.pump();
    expect(container.read(onboardingProvider).subjects, ['CS']);
    await tester.tap(find.text('CS'));
    await tester.pump();

    await _continue(tester);
    expect(find.byType(ObHoursScreen), findsOneWidget);
    expect(find.byType(ObMoodScreen), findsNothing);
  });
}
