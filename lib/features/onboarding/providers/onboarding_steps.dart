import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../freeze/providers/freeze_controller.dart';
import 'onboarding_controller.dart';

/// The onboarding steps, in order (CLAUDE.md "Onboarding v2"). The under-18
/// block screen and the loading screen are not steps; the block screen draws
/// the age step's dots.
enum ObStep { age, consent, referral, source, name, study, mood, hours, freeze, apps, prism }

/// The steps this student will actually see, in order. The progress dots are
/// drawn from this, so a step that is skipped leaves no gap behind it:
///
/// * `mood` ("How do you feel about each?") rates each chosen subject, so with
///   no subjects there is nothing to ask and it is skipped.
/// * `freeze` and `apps` only exist on a phone that can run App freeze.
final onboardingStepsProvider = Provider<List<ObStep>>((ref) {
  final hasSubjects = ref.watch(onboardingProvider.select((d) => d.subjects.isNotEmpty));
  final freeze = ref.watch(appFreezeAvailableProvider);
  return [
    for (final step in ObStep.values)
      if (!(step == ObStep.mood && !hasSubjects) &&
          !((step == ObStep.freeze || step == ObStep.apps) && !freeze))
        step,
  ];
});
