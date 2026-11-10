// v1's haptics are kept alongside the architecture's: the touchpoints §4 does
// not list still play, with v1's own patterns and tiers.

import 'package:aqademiq/services/haptics/haptic_lexicon.dart';
import 'package:aqademiq/services/haptics/haptic_moments.dart';
import 'package:flutter_test/flutter_test.dart';

double _peak(HapticSpec s) => [
      for (final e in s.ios)
        switch (e) {
          IosTap(:final intensity) => intensity,
          IosCurve(:final peak) => peak,
        },
    ].reduce((a, b) => a > b ? a : b);

void main() {
  test('every v1 touchpoint has a moment with a feel', () {
    for (final m in [
      HapticMoment.streakMilestone,
      HapticMoment.guestUpgraded,
      HapticMoment.onboardingFinished,
      HapticMoment.subjectCreated,
      HapticMoment.taskMoved,
      HapticMoment.itemDeleted,
      HapticMoment.volumeStep,
    ]) {
      expect(specFor(m).ios, isNotEmpty, reason: '$m');
    }
  });

  test("v1's numbers are kept exactly", () {
    expect(_peak(specFor(HapticMoment.itemDeleted)), 1);
    expect(specFor(HapticMoment.itemDeleted).ios.last.at, const Duration(milliseconds: 130));
    expect(specFor(HapticMoment.taskMoved).ios.last.at, const Duration(milliseconds: 70));
    expect(specFor(HapticMoment.onboardingFinished).ios.map((e) => e.at.inMilliseconds), [0, 110, 220]);
    expect(specFor(HapticMoment.streakMilestone).ios.whereType<IosTap>().map((e) => e.at.inMilliseconds), [260, 380]);
  });

  test("v1's tiers: earned and warning are Essential, the rest Full", () {
    expect(HapticMoment.streakMilestone.tier, HapticTier.essential);
    expect(HapticMoment.itemDeleted.tier, HapticTier.essential);
    expect(HapticMoment.subjectCreated.tier, HapticTier.full);
    expect(HapticMoment.volumeStep.stream, isTrue);
  });
}
