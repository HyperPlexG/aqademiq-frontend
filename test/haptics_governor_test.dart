// The governor is the part of the haptics layer worth testing, and it is
// testable precisely because it takes the setting and the focus status as
// inputs instead of reaching into providers.
//
// Every rule below fails SILENTLY in production. A haptic that should have been
// suppressed is a buzz nobody files a bug about; a haptic that should have
// fired is an absence nobody notices until the feature feels cheap. So these
// are not "does the class work" tests — they are the only place the rules are
// written down as behaviour rather than prose.
//
// Spec §4 and §6.5; guide §1.3 and §5.

import 'package:aqademiq/services/haptics/haptic_governor.dart';
import 'package:aqademiq/services/haptics/haptic_patterns.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hand-cranked clock, so a 40–60 ms rule is not tested with a real 40 ms.
class _Clock {
  DateTime _now = DateTime(2026, 8, 27, 9);

  DateTime call() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// Drives a governor with no bindings, no widget tree and no platform channel.
class _Harness {
  _Harness() {
    governor = HapticGovernor(
      play: (event, _) => played.add(event),
      clock: clock.call,
      schedule: _pendingFlushes.add,
    );
  }

  final clock = _Clock();
  final played = <HapticEvent>[];
  final _pendingFlushes = <void Function()>[];
  late final HapticGovernor governor;

  /// End the current coalescing frame.
  void endFrame() {
    final due = List<void Function()>.of(_pendingFlushes);
    _pendingFlushes.clear();
    for (final flush in due) {
      flush();
    }
  }

  void submit(
    HapticEvent event, {
    HapticSetting setting = HapticSetting.full,
    bool focusRunning = false,
    bool reducedMotion = false,
  }) =>
      governor.submit(
        event,
        setting: setting,
        focusRunning: focusRunning,
        reducedMotion: reducedMotion,
      );

  /// Submit one event in a frame of its own, well clear of the interval floor.
  void fireAlone(
    HapticEvent event, {
    HapticSetting setting = HapticSetting.full,
    bool focusRunning = false,
    bool reducedMotion = false,
  }) {
    clock.advance(const Duration(seconds: 1));
    submit(
      event,
      setting: setting,
      focusRunning: focusRunning,
      reducedMotion: reducedMotion,
    );
    endFrame();
  }
}

/// One event per tier, for the setting tests.
const _oneOfEach = [
  HapticEvent.taskCompleted, // Tier 1
  HapticEvent.taskCreated, // Tier 2
  HapticEvent.wheelItem, // Tier 3
  HapticEvent.saveFailed, // Tier 4
];

void main() {
  group('the user setting', () {
    test('Off fires nothing, ever', () {
      final h = _Harness();
      for (final event in _oneOfEach) {
        h.fireAlone(event, setting: HapticSetting.off);
      }
      expect(h.played, isEmpty);
    });

    test('Essential keeps Tiers 1 and 4 and drops Tiers 2 and 3', () {
      final h = _Harness();
      for (final event in _oneOfEach) {
        h.fireAlone(event, setting: HapticSetting.essential);
      }
      expect(h.played, [HapticEvent.taskCompleted, HapticEvent.saveFailed]);
    });

    test('Full lets every tier through', () {
      final h = _Harness();
      for (final event in _oneOfEach) {
        h.fireAlone(event);
      }
      expect(h.played, _oneOfEach);
    });
  });

  group('the OS reduce-motion setting sits above the app one', () {
    test('it clamps Full down to Essential', () {
      final h = _Harness();
      for (final event in _oneOfEach) {
        h.fireAlone(event, reducedMotion: true);
      }
      expect(h.played, [HapticEvent.taskCompleted, HapticEvent.saveFailed]);
    });

    test('it can never loosen Off', () {
      // The app setting may be stricter than the OS, never the reverse.
      final h = _Harness();
      for (final event in _oneOfEach) {
        h.fireAlone(event, setting: HapticSetting.off, reducedMotion: true);
      }
      expect(h.played, isEmpty);
    });
  });

  group('focus-session suppression', () {
    // The strictest rule in the spec (§4.2). The entire promise of /focus is
    // undisturbed attention, and it is also how haptics stays out of Prism's
    // way.
    test('nothing fires while a session runs, except freeze / resume / end', () {
      final h = _Harness();
      for (final event in HapticEvent.values) {
        h.fireAlone(event, focusRunning: true);
      }
      expect(
        h.played.toSet(),
        HapticGovernor.sessionTransitions,
      );
    });

    test('focusStarted is NOT exempt', () {
      // Deliberate, and the reason `FocusController.start` fires its haptic in
      // the window before the status flips to running. If someone moves that
      // call below the state assignment, the event silently disappears and this
      // is the test that explains why.
      final h = _Harness()..fireAlone(HapticEvent.focusStarted, focusRunning: true);
      expect(h.played, isEmpty);

      h.fireAlone(HapticEvent.focusStarted);
      expect(h.played, [HapticEvent.focusStarted]);
    });

    test('an idle app is unaffected', () {
      final h = _Harness()..fireAlone(HapticEvent.taskCompleted);
      expect(h.played, [HapticEvent.taskCompleted]);
    });
  });

  group('the minimum interval floor', () {
    test('two events 10 ms apart fire once', () {
      final h = _Harness()..fireAlone(HapticEvent.taskCompleted);
      h.clock.advance(const Duration(milliseconds: 10));
      h
        ..submit(HapticEvent.taskCreated)
        ..endFrame();
      expect(h.played, [HapticEvent.taskCompleted]);
    });

    test('the second fires once the floor has passed', () {
      final h = _Harness()..fireAlone(HapticEvent.taskCompleted);
      h.clock.advance(HapticGovernor.minInterval);
      h
        ..submit(HapticEvent.taskCreated)
        ..endFrame();
      expect(h.played, [HapticEvent.taskCompleted, HapticEvent.taskCreated]);
    });

    test('a suppressed event does not restart the floor', () {
      // The floor is measured against what actually fired, so a burst of
      // dropped events cannot starve the next real one.
      final h = _Harness()..fireAlone(HapticEvent.taskCompleted);
      h.clock.advance(const Duration(milliseconds: 30));
      // Dropped by the floor.
      h
        ..submit(HapticEvent.taskCreated)
        ..endFrame();
      h.clock.advance(const Duration(milliseconds: 30)); // 60 ms since the fire
      h
        ..submit(HapticEvent.moodLogged)
        ..endFrame();
      expect(h.played, [HapticEvent.taskCompleted, HapticEvent.moodLogged]);
    });
  });

  group('burst coalescing', () {
    test('three events in one frame fire only the highest tier', () {
      final h = _Harness()
        ..submit(HapticEvent.wheelItem) // Tier 3
        ..submit(HapticEvent.taskCompleted) // Tier 1
        ..submit(HapticEvent.taskCreated) // Tier 2
        ..endFrame();
      expect(h.played, [HapticEvent.taskCompleted]);
    });

    test('order within the frame does not matter', () {
      final h = _Harness()
        ..submit(HapticEvent.taskCompleted)
        ..submit(HapticEvent.wheelItem)
        ..endFrame();
      expect(h.played, [HapticEvent.taskCompleted]);
    });

    test('the next frame is a fresh contest', () {
      final h = _Harness()
        ..submit(HapticEvent.taskCompleted)
        ..submit(HapticEvent.wheelItem)
        ..endFrame();
      h.clock.advance(const Duration(seconds: 1));
      h
        ..submit(HapticEvent.moodLogged)
        ..endFrame();
      expect(h.played, [HapticEvent.taskCompleted, HapticEvent.moodLogged]);
    });
  });

  group('fling suppression', () {
    // During a fling the user is not reading positions, so the ticks convey
    // nothing and merely blur into a rattle (§4.4).
    test('a fast wheel stops ticking and stays stopped', () {
      final h = _Harness();
      // 20 ms per item — a flick, not a selection.
      for (var i = 0; i < 12; i++) {
        h
          ..submit(HapticEvent.wheelItem)
          ..endFrame();
        h.clock.advance(const Duration(milliseconds: 20));
      }
      // Only the first tick, before the run was recognised as a fling. Note the
      // total elapsed time is well past the interval floor, so nothing but the
      // fling rule can explain the silence.
      expect(h.played, [HapticEvent.wheelItem]);
    });

    test('a deliberately turned wheel ticks every item', () {
      final h = _Harness();
      for (var i = 0; i < 4; i++) {
        h.clock.advance(const Duration(milliseconds: 150));
        h
          ..submit(HapticEvent.wheelItem)
          ..endFrame();
      }
      expect(h.played, List.filled(4, HapticEvent.wheelItem));
    });

    test('a fling that slows down starts ticking again', () {
      final h = _Harness();
      for (var i = 0; i < 8; i++) {
        h
          ..submit(HapticEvent.wheelItem)
          ..endFrame();
        h.clock.advance(const Duration(milliseconds: 20));
      }
      expect(h.played, hasLength(1));
      // The wheel settles.
      h.clock.advance(const Duration(milliseconds: 300));
      h
        ..submit(HapticEvent.wheelItem)
        ..endFrame();
      expect(h.played, hasLength(2));
    });

    test('only detents are flung — a burst of Tier 1 is not', () {
      // Fling suppression is about continuous input. It must not become a
      // general rate limiter; that is what the interval floor is for.
      final h = _Harness();
      for (var i = 0; i < 6; i++) {
        h.clock.advance(const Duration(milliseconds: 20));
        h
          ..submit(HapticEvent.taskCompleted)
          ..endFrame();
      }
      // Thinned by the 50 ms floor, but never by the fling rule.
      expect(h.played, isNotEmpty);
      expect(h.played.every((e) => e == HapticEvent.taskCompleted), isTrue);
    });
  });

  group('the vocabulary', () {
    test('every event resolves to a tier', () {
      // Cheap, but it is the guard on §8.1: a new event cannot be added without
      // naming its tier, because the enum will not compile without one.
      for (final event in HapticEvent.values) {
        expect(HapticTier.values, contains(event.tier));
      }
    });

    test('the tier counts match spec §3', () {
      int count(HapticTier tier) =>
          HapticEvent.values.where((e) => e.tier == tier).length;
      expect(count(HapticTier.earned), 5, reason: 'Tier 1 — earned moments');
      expect(count(HapticTier.confirmation), 10, reason: 'Tier 2');
      expect(
        count(HapticTier.detent),
        5,
        reason: 'Tier 3 — the spec lists four, plus the long-press tick that '
            "§7's Plan budget names and §3 omits",
      );
      expect(count(HapticTier.warning), 3, reason: 'Tier 4 — warnings');
      expect(HapticEvent.values, hasLength(23));
    });
  });
}
