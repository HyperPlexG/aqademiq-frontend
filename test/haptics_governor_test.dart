// The budget rules (haptic architecture §3) — the ones that fail silently.
//
// A plain class with injected clock and scheduler, so every rule is checked
// with no widget tree and no platform channel.

import 'package:aqademiq/services/haptics/haptic_governor.dart';
import 'package:aqademiq/services/haptics/haptic_lexicon.dart';
import 'package:aqademiq/services/haptics/haptic_moments.dart';
import 'package:flutter_test/flutter_test.dart';

class _Rig {
  _Rig() {
    governor = HapticGovernor(
      play: played.add,
      stop: stopped.add,
      clock: () => now,
      schedule: (flush) => pending = flush,
    );
  }

  late final HapticGovernor governor;
  final played = <AdmittedHaptic>[];
  final stopped = <int>[];
  DateTime now = DateTime(2026, 11, 8, 9);
  void Function()? pending;

  void offer(
    HapticMoment m, {
    HapticSetting setting = HapticSetting.full,
    bool running = false,
    bool constrained = false,
    bool landed = false,
    int step = 0,
  }) {
    governor.submit(
      m,
      specFor(m, step: step),
      setting: setting,
      focusRunning: running,
      constrained: constrained,
      landed: landed,
    );
    flush();
  }

  void flush() {
    final f = pending;
    pending = null;
    f?.call();
  }

  void advance(Duration d) => now = now.add(d);

  double peak(AdmittedHaptic h) => h.spec.ios.whereType<IosTap>().fold(0, (m, e) => e.intensity > m ? e.intensity : m);
}

void main() {
  group('setting', () {
    test('Essential is the default for a student who never picked', () {
      expect(HapticSetting.fromStorageKey(null), HapticSetting.essential);
      expect(HapticSetting.fromStorageKey('full'), HapticSetting.full);
      expect(HapticSetting.fromStorageKey('off'), HapticSetting.off);
    });

    test('Off plays nothing; Essential only the essential moments; Full all', () {
      final r = _Rig()
        ..offer(HapticMoment.sessionPause, setting: HapticSetting.off)
        ..offer(HapticMoment.taskChecked, setting: HapticSetting.essential);
      expect(r.played, isEmpty);
      r.offer(HapticMoment.sessionPause, setting: HapticSetting.essential);
      expect(r.played.single.spec.name, 'aq.crystallise');
      r.offer(HapticMoment.taskChecked);
      expect(r.played.last.spec.name, 'aq.latch');
    });

    test('Low Power, heat or reduce-motion drop Full to Essential, never further', () {
      final r = _Rig()..offer(HapticMoment.tabSwitch, constrained: true);
      expect(r.played, isEmpty);
      r.offer(HapticMoment.freezeNow, constrained: true);
      expect(r.played, hasLength(1));
      expect(HapticGovernor.admits(HapticSetting.off, HapticTier.essential, constrained: true), isFalse);
    });

    test("the haptics sheet's preview plays whatever the setting was", () {
      final r = _Rig()..offer(HapticMoment.previewOff, setting: HapticSetting.off);
      expect(r.played.single.spec.name, 'aq.unlatch');
    });

    test('Essential holds exactly the moments §3 lists', () {
      final essential = {
        for (final m in HapticMoment.values)
          if (m.tier == HapticTier.essential) m,
      };
      expect(essential, {
        HapticMoment.failure,
        HapticMoment.sessionStart,
        HapticMoment.sessionPause,
        HapticMoment.sessionResume,
        HapticMoment.sessionEndEarly,
        HapticMoment.sessionComplete,
        HapticMoment.freezeNow,
        HapticMoment.keepOnlyThese,
        HapticMoment.thawBreath,
        HapticMoment.thawBreathLong,
        HapticMoment.thawConfirmed,
        HapticMoment.deepFreezeHolds,
        HapticMoment.frostEndEarly,
        HapticMoment.thawEverythingHold,
        HapticMoment.thawEverythingDone,
        HapticMoment.deleteAccountHold,
        HapticMoment.deleteAccountDone,
      });
    });
  });

  group('running session', () {
    test('nothing the student did not trigger', () {
      final r = _Rig()
        ..offer(HapticMoment.proposalsArrived, running: true)
        ..offer(HapticMoment.refreeze, running: true);
      expect(r.played, isEmpty);
    });

    test('what the student does still answers — pausing, ending', () {
      final r = _Rig()
        ..offer(HapticMoment.sessionPause, running: true)
        ..advance(const Duration(seconds: 5))
        ..offer(HapticMoment.sessionEndEarly, running: true);
      expect(r.played.map((h) => h.spec.name), ['aq.crystallise', 'aq.melt']);
    });
  });

  group('wheels', () {
    test('at most one tick per 40 ms', () {
      final r = _Rig()..offer(HapticMoment.wheelStep);
      r
        ..advance(const Duration(milliseconds: 20))
        ..offer(HapticMoment.wheelStep);
      expect(r.played, hasLength(1));
      r
        ..advance(const Duration(milliseconds: 25))
        ..offer(HapticMoment.wheelStep);
      expect(r.played, hasLength(2));
    });

    test('faster than 25 steps a second plays at half strength; the landing at full', () {
      final r = _Rig()..offer(HapticMoment.wheelStep);
      final full = r.peak(r.played.single);
      // 30 ms between steps is >25 a second. Every other one clears the 40 ms
      // limiter and plays — at half strength.
      for (var i = 0; i < 4; i++) {
        r
          ..advance(const Duration(milliseconds: 30))
          ..offer(HapticMoment.wheelStep);
      }
      expect(r.played.length, greaterThan(1));
      expect(r.peak(r.played.last), closeTo(full / 2, 1e-9));

      r
        ..advance(const Duration(milliseconds: 10))
        ..offer(HapticMoment.wheelStep, landed: true);
      expect(r.peak(r.played.last), closeTo(full, 1e-9));
    });

    test('a slow, deliberate turn is full strength and never decays', () {
      final r = _Rig();
      for (var i = 0; i < 10; i++) {
        r
          ..offer(HapticMoment.wheelStep)
          ..advance(const Duration(milliseconds: 200));
      }
      expect(r.played, hasLength(10));
      expect(r.played.map(r.peak).toSet(), hasLength(1));
    });
  });

  group('one frame, one haptic', () {
    test('the essential moment wins a collision; a tie goes to the later', () {
      final r = _Rig();
      r.governor
        ..submit(HapticMoment.taskChecked, specFor(HapticMoment.taskChecked), setting: HapticSetting.full, focusRunning: false)
        ..submit(HapticMoment.freezeNow, specFor(HapticMoment.freezeNow), setting: HapticSetting.full, focusRunning: false)
        ..submit(HapticMoment.chipSelect, specFor(HapticMoment.chipSelect), setting: HapticSetting.full, focusRunning: false);
      r.flush();
      expect(r.played.single.spec.name, 'aq.crystallise');

      r.governor
        ..submit(HapticMoment.taskChecked, specFor(HapticMoment.taskChecked), setting: HapticSetting.full, focusRunning: false)
        ..submit(HapticMoment.chipSelect, specFor(HapticMoment.chipSelect), setting: HapticSetting.full, focusRunning: false);
      r.flush();
      expect(r.played.last.spec.name, 'aq.tick');
    });
  });

  group('signatures', () {
    test('two within 2 s: the earlier is stopped and the later plays', () {
      final r = _Rig()..offer(HapticMoment.sessionPause);
      final first = r.played.single.id;
      r
        ..advance(const Duration(milliseconds: 800))
        ..offer(HapticMoment.sessionResume);
      expect(r.played, hasLength(2));
      expect(r.stopped, [first]);
    });

    test('2 s apart, nothing is stopped', () {
      final r = _Rig()
        ..offer(HapticMoment.sessionPause)
        ..advance(const Duration(seconds: 2))
        ..offer(HapticMoment.sessionResume);
      expect(r.stopped, isEmpty);
    });

    test('a tick is not a signature', () {
      final r = _Rig()
        ..offer(HapticMoment.sessionPause)
        ..advance(const Duration(milliseconds: 300))
        ..offer(HapticMoment.chipSelect);
      expect(r.stopped, isEmpty);
    });
  });

  group('repetition', () {
    test('85% of the last strength per repeat within 10 minutes, never below 50%', () {
      final r = _Rig();
      for (var i = 0; i < 8; i++) {
        r
          ..offer(HapticMoment.taskChecked)
          ..advance(const Duration(seconds: 30));
      }
      final peaks = r.played.map(r.peak).toList();
      final base = peaks.first;
      expect(peaks[1], closeTo(base * 0.85, 1e-9));
      expect(peaks[2], closeTo(base * 0.85 * 0.85, 1e-9));
      expect(peaks.last, closeTo(base * 0.5, 1e-9));
    });

    test('10 idle minutes reset it', () {
      final r = _Rig()
        ..offer(HapticMoment.taskChecked)
        ..advance(const Duration(seconds: 30))
        ..offer(HapticMoment.taskChecked)
        ..advance(const Duration(minutes: 10))
        ..offer(HapticMoment.taskChecked);
      expect(r.peak(r.played.last), closeTo(r.peak(r.played.first), 1e-9));
    });

    test('counted per pattern, not per moment: a toggle on then a task check-off are both latches', () {
      final r = _Rig()
        ..offer(HapticMoment.toggleOn)
        ..advance(const Duration(seconds: 5))
        ..offer(HapticMoment.taskChecked);
      expect(r.peak(r.played.last), closeTo(r.peak(r.played.first) * 0.85, 1e-9));
    });

    test('the system success and error are never softened', () {
      final r = _Rig();
      for (var i = 0; i < 3; i++) {
        r
          ..offer(HapticMoment.failure)
          ..advance(const Duration(seconds: 3));
      }
      expect(r.played.map((h) => h.spec).toSet(), hasLength(1));
    });
  });

  group('holds', () {
    test('a hold is admitted under its tier and silenced by Off', () {
      final r = _Rig();
      expect(
        r.governor.admitHold(HapticMoment.thawBreath, Aq.breath, setting: HapticSetting.essential, focusRunning: false),
        isNotNull,
      );
      expect(
        r.governor.admitHold(HapticMoment.thawBreath, Aq.breath, setting: HapticSetting.off, focusRunning: false),
        isNull,
      );
    });
  });
}
