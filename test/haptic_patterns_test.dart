// The pattern table is design, and design regresses quietly: nothing crashes
// when a detent drops below the threshold where a motor can be felt, or when
// two events that must be distinguishable become the same vibration. These
// tests pin the properties that carry meaning, not the exact numbers — tuning
// is expected, collapsing is not.
import 'package:aqademiq/services/haptics/haptic_driver.dart';
import 'package:aqademiq/services/haptics/haptic_governor.dart';
import 'package:aqademiq/services/haptics/haptic_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records instead of vibrating.
class _RecordingDriver implements HapticDriver {
  final List<HapticPattern> played = [];

  @override
  Future<void> play(HapticPattern pattern) async => played.add(pattern);
}

double _peak(HapticPattern p) =>
    p.beats.map((b) => b.intensity).reduce((a, b) => a > b ? a : b);

void main() {
  group('every event has a feel', () {
    test('all 23 resolve to a non-empty pattern', () {
      for (final event in HapticEvent.values) {
        final pattern = patternFor(event);
        expect(pattern.beats, isNotEmpty, reason: '$event has no beats');
      }
    });

    test('nothing is silent — every beat carries real energy', () {
      for (final event in HapticEvent.values) {
        for (final beat in patternFor(event).beats) {
          expect(
            beat.intensity,
            greaterThan(0),
            reason: '$event has a zero-intensity beat, which is just a pause',
          );
          expect(beat.intensity, lessThanOrEqualTo(1));
          expect(beat.sharpness, inInclusiveRange(0, 1));
        }
      }
    });

    test('beats are ordered and never overlap themselves', () {
      for (final event in HapticEvent.values) {
        final beats = patternFor(event).beats;
        for (var i = 1; i < beats.length; i++) {
          expect(
            beats[i].at,
            greaterThanOrEqualTo(beats[i - 1].at),
            reason: '$event beat $i starts before the one before it',
          );
        }
      }
    });
  });

  group('the perceptibility floor', () {
    // The reason this file exists. A 20 ms pulse is imperceptible on an
    // Android LRA however high its amplitude — the motor is still spinning up
    // when it ends — so the old selectionClick detents felt like nothing at all
    // on device. Every tap now carries an explicit Android pulse length.
    // Asserted against a literal, deliberately, NOT against `detentPulse`.
    // Comparing the constant to itself is a tautology: lowering it to the 20 ms
    // that could not be felt on device would move the goalpost with it and the
    // test would still pass. This is the number, independent of the code.
    const perceptible = Duration(milliseconds: 50);

    test('no tap is shorter than the measured perceptibility floor', () {
      for (final event in HapticEvent.values) {
        for (final beat in patternFor(event).beats) {
          if (beat.shape != HapticShape.tap) continue;
          expect(
            beat.androidPulse,
            greaterThanOrEqualTo(perceptible),
            reason: '$event has a tap too short to feel on an Android motor',
          );
        }
      }
    });

    test('the detent constant itself clears the floor', () {
      expect(detentPulse, greaterThanOrEqualTo(perceptible));
      expect(longPressPulse, greaterThanOrEqualTo(perceptible));
      expect(confirmPulse, greaterThanOrEqualTo(perceptible));
      expect(earnedPulse, greaterThanOrEqualTo(perceptible));
    });

    test('the floor stays under the fling gap, or scrolls would smear', () {
      // Detents arrive about flingGap apart during a deliberate scroll. A pulse
      // longer than that would still be running when the next one starts and a
      // row of distinct ticks would be felt as one continuous buzz.
      expect(detentPulse, lessThan(HapticGovernor.flingGap));
    });

    test('the long-press may exceed it — nothing follows a long-press', () {
      expect(longPressPulse, greaterThan(detentPulse));
      final beat = patternFor(HapticEvent.longPressTick).beats.single;
      expect(beat.androidPulse, longPressPulse);
    });

    test('every detent is strong enough to notice', () {
      // Tier 3 is meant to be subtle, not absent. 0.4 is the floor below which
      // a tick stops registering on a mid-range phone.
      for (final event in HapticEvent.values.where(
        (e) => e.tier == HapticTier.detent,
      )) {
        final steps = event == HapticEvent.moodRampStep ? 5 : 1;
        for (var i = 0; i < steps; i++) {
          expect(
            _peak(patternFor(event, rampStep: i)),
            greaterThanOrEqualTo(0.4),
            reason: '$event (step $i) is too faint to feel',
          );
        }
      }
    });
  });

  group('the mood ramp', () {
    test('all five positions are genuinely distinct', () {
      // The old ramp collapsed onto three impulse strengths, so Rough/Tired and
      // OK/Good were literally identical vibrations. §5.1 asked for a ramp.
      final seen = <(double, double)>{};
      for (var i = 0; i < 5; i++) {
        final beat = patternFor(HapticEvent.moodRampStep, rampStep: i).beats.single;
        seen.add((beat.intensity, beat.sharpness));
      }
      expect(seen, hasLength(5));
    });

    test('it rises monotonically — softer at Rough, sharper at Great', () {
      var lastIntensity = 0.0;
      var lastSharpness = 0.0;
      for (var i = 0; i < 5; i++) {
        final beat = patternFor(HapticEvent.moodRampStep, rampStep: i).beats.single;
        expect(beat.intensity, greaterThan(lastIntensity), reason: 'step $i');
        expect(beat.sharpness, greaterThan(lastSharpness), reason: 'step $i');
        lastIntensity = beat.intensity;
        lastSharpness = beat.sharpness;
      }
    });

    test('an out-of-range step clamps instead of throwing', () {
      expect(() => patternFor(HapticEvent.moodRampStep, rampStep: -3), returnsNormally);
      expect(() => patternFor(HapticEvent.moodRampStep, rampStep: 99), returnsNormally);
      expect(
        patternFor(HapticEvent.moodRampStep, rampStep: 99).beats.single.intensity,
        patternFor(HapticEvent.moodRampStep, rampStep: 4).beats.single.intensity,
      );
    });
  });

  group('events that must not feel alike', () {
    // Each pair below can be felt within seconds of the other, so a user who
    // cannot tell them apart loses real information.
    void expectDistinct(HapticEvent a, HapticEvent b) {
      final wireA = patternFor(a).toWire().toString();
      final wireB = patternFor(b).toWire().toString();
      expect(wireA, isNot(wireB), reason: '$a and $b feel identical');
    }

    test('freeze and resume are inverses, not twins', () {
      expectDistinct(HapticEvent.sessionFrozen, HapticEvent.sessionResumed);
    });

    test('a finished session feels nothing like an abandoned one', () {
      expectDistinct(HapticEvent.focusCompleted, HapticEvent.sessionEndedEarly);
    });

    test('freezing a session is not completing a task', () {
      // These were both mediumImpact before, i.e. the same vibration for the
      // app's signature reward and one of its most routine controls.
      expectDistinct(HapticEvent.sessionFrozen, HapticEvent.taskCompleted);
    });

    test('a failed save is not a confirmation', () {
      expectDistinct(HapticEvent.saveFailed, HapticEvent.taskCreated);
    });

    test('a long-press tick is not a scroll tick', () {
      expectDistinct(HapticEvent.longPressTick, HapticEvent.wheelItem);
    });

    test('ending early has no click in it at all', () {
      // The melted end (§5.2) is carried entirely by the absence of an impact.
      final beats = patternFor(HapticEvent.sessionEndedEarly).beats;
      expect(beats.every((b) => b.shape == HapticShape.hold), isTrue);
    });
  });

  group('spans', () {
    test('a detent is over almost immediately', () {
      for (final event in HapticEvent.values.where(
        (e) => e.tier == HapticTier.detent,
      )) {
        expect(
          hapticSpanOf(event, 0),
          lessThanOrEqualTo(longPressPulse),
          reason: '$event occupies the motor too long for a detent',
        );
      }
    });

    test('earned moments are the only long ones', () {
      expect(hapticSpanOf(HapticEvent.focusCompleted, null).inMilliseconds, greaterThan(300));
      expect(hapticSpanOf(HapticEvent.streakMilestone, null).inMilliseconds, greaterThan(300));
    });

    test('the span covers the last beat, not just its start', () {
      // The governor stays quiet for this long; measuring from a beat's start
      // would let a tick land inside the final hold of a celebration.
      final pattern = patternFor(HapticEvent.focusCompleted);
      final last = pattern.beats.last;
      expect(pattern.span, greaterThan(last.at));
      expect(pattern.span, last.at + last.duration);
    });
  });

  group('the governor stays quiet for a whole pattern', () {
    test('a long celebration blocks a tick that lands inside it', () {
      final played = <HapticEvent>[];
      var now = DateTime(2026);
      final governor = HapticGovernor(
        play: (event, _) => played.add(event),
        clock: () => now,
        schedule: (flush) => flush(),
      );

      void submit(HapticEvent event) => governor.submit(
            event,
            setting: HapticSetting.full,
            focusRunning: false,
            reducedMotion: false,
          );

      submit(HapticEvent.focusCompleted);
      // 200 ms in: past the 50 ms floor, but the third beat has not started.
      now = now.add(const Duration(milliseconds: 200));
      submit(HapticEvent.wheelItem);
      expect(played, [HapticEvent.focusCompleted]);

      // Once the whole pattern is done, the motor is free again.
      now = now.add(const Duration(milliseconds: 300));
      submit(HapticEvent.wheelItem);
      expect(played, [HapticEvent.focusCompleted, HapticEvent.wheelItem]);
    });

    test('a short event still only costs the old interval floor', () {
      final played = <HapticEvent>[];
      var now = DateTime(2026);
      final governor = HapticGovernor(
        play: (event, _) => played.add(event),
        clock: () => now,
        schedule: (flush) => flush(),
      );
      void submit(HapticEvent event) => governor.submit(
            event,
            setting: HapticSetting.full,
            focusRunning: false,
            reducedMotion: false,
          );

      submit(HapticEvent.wheelItem);
      now = now.add(HapticGovernor.minInterval);
      submit(HapticEvent.taskCreated);
      expect(played, [HapticEvent.wheelItem, HapticEvent.taskCreated]);
    });
  });

  group('the driver', () {
    test('playHapticEvent reaches the driver with the right pattern', () async {
      final driver = _RecordingDriver();
      hapticDriver = driver;
      addTearDown(resetHapticDriver);

      await playHapticEvent(HapticEvent.sessionFrozen);

      expect(driver.played, hasLength(1));
      expect(driver.played.single.beats.first.sharpness, 1);
    });

    test('the ramp step reaches the driver', () async {
      final driver = _RecordingDriver();
      hapticDriver = driver;
      addTearDown(resetHapticDriver);

      await playHapticEvent(HapticEvent.moodRampStep, rampStep: 4);
      await playHapticEvent(HapticEvent.moodRampStep, rampStep: 0);

      expect(
        driver.played.first.beats.single.intensity,
        greaterThan(driver.played.last.beats.single.intensity),
      );
    });

    test('a device with no native channel never throws', () async {
      // Unit tests have nothing behind `aqademiq/haptics`, which is exactly the
      // desktop-embedder case. Haptics is enrichment; it must degrade to
      // silence rather than reach the error handler.
      PlatformHapticDriver.resetNativeProbe();
      hapticDriver = const PlatformHapticDriver();
      addTearDown(resetHapticDriver);

      await expectLater(playHapticEvent(HapticEvent.taskCompleted), completes);
    });
  });

  group('the wire format', () {
    test('a tap sends its Android pulse as the duration', () {
      final wire = patternFor(HapticEvent.longPressTick).toWire().single;
      expect(wire['shape'], 'tap');
      expect(wire['ms'], longPressPulse.inMilliseconds);
    });

    test('a hold sends its real duration', () {
      final wire = patternFor(HapticEvent.saveFailed).toWire().single;
      expect(wire['shape'], 'hold');
      expect(wire['ms'], 250);
    });

    test('offsets survive so a pattern keeps its rhythm', () {
      final wire = patternFor(HapticEvent.destructiveConfirmed).toWire();
      expect(wire.map((b) => b['at']), [0, 130]);
    });

    test('every value crosses the channel as a primitive', () {
      // A MethodChannel can only carry standard types; a Duration or an enum
      // would throw at the boundary on a real device and nowhere in a test.
      for (final event in HapticEvent.values) {
        for (final beat in patternFor(event).toWire()) {
          for (final value in beat.values) {
            expect(
              value is num || value is String,
              isTrue,
              reason: '$event sends a ${value.runtimeType}',
            );
          }
        }
      }
    });
  });

  test('the vocabulary is still 23 events in 4 tiers', () {
    expect(HapticEvent.values, hasLength(23));
    expect(HapticTier.earned.name, 'earned');
    expect(HapticTier.values, hasLength(4));
  });
}
