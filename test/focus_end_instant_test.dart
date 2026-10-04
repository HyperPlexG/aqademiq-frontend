import 'package:aqademiq/data/models/enums.dart';
import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The end instant and the freeze accounting behind it.
///
/// Everything ambient — the Live Activity, the Dynamic Island, the Android
/// chronometer — counts down from [FocusSession.endsAt] without the app being
/// involved, so these are the semantics the OS will render on its own. A frozen
/// session that keeps counting down on a lock screen is worse than shipping no
/// lock screen at all, which is why the freeze cases are here in full.
void main() {
  group('meltStage', () {
    // Five stages is the entire animation budget out there (kMeltStages), so
    // the boundaries are a contract between three renderers, not a detail.
    test('starts at 0 and ends at the last stage', () {
      const start = FocusSession(id: 's', durationMin: 10);
      expect(start.meltStage, 0);

      const done = FocusSession(id: 's', durationMin: 10, elapsedSec: 600);
      expect(done.meltStage, kMeltStages - 1);
    });

    test('advances one stage per fifth of the session', () {
      // 10 minutes = 600s, so a stage is 120s.
      int stageAt(int sec) =>
          FocusSession(id: 's', durationMin: 10, elapsedSec: sec).meltStage;

      expect(stageAt(0), 0);
      expect(stageAt(119), 0);
      expect(stageAt(120), 1);
      expect(stageAt(359), 2);
      expect(stageAt(480), 4);
    });

    test('never leaves the drawable range, even past the planned end', () {
      const overrun = FocusSession(id: 's', durationMin: 10, elapsedSec: 9999);
      expect(overrun.meltStage, kMeltStages - 1);

      const zeroLength = FocusSession(id: 's', durationMin: 0);
      expect(zeroLength.meltStage, 0);
    });
  });

  group('remaining', () {
    test('counts down from endsAt while running', () {
      final session = FocusSession(
        id: 's',
        durationMin: 25,
        status: FocusStatus.running,
        endsAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      expect(session.remaining.inSeconds, closeTo(600, 2));
    });

    test('holds still while frozen', () {
      // Frozen five minutes before the end: the answer must stay five minutes
      // however long the session is held, because held time is not spent time.
      final frozenAt = DateTime.now().subtract(const Duration(minutes: 3));
      final session = FocusSession(
        id: 's',
        durationMin: 25,
        status: FocusStatus.paused,
        endsAt: frozenAt.add(const Duration(minutes: 5)),
        frozenAt: frozenAt,
      );

      expect(session.isFrozen, isTrue);
      expect(session.remaining, const Duration(minutes: 5));
    });

    test('never goes negative once the end has passed', () {
      final session = FocusSession(
        id: 's',
        durationMin: 25,
        status: FocusStatus.running,
        endsAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      expect(session.remaining, Duration.zero);
    });

    test('falls back to the planned duration before a session starts', () {
      // No end instant exists until start(); the configure screen still has to
      // show a sensible number.
      const idle = FocusSession(id: '', durationMin: 25);
      expect(idle.remaining, const Duration(minutes: 25));
    });
  });

  group('FocusController', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('start stamps an end instant a whole duration away', () async {
      final controller = container.read(focusControllerProvider.notifier)
        ..configure(durationMin: 25);
      await controller.start();

      final session = container.read(focusControllerProvider);
      expect(session.status, FocusStatus.running);
      expect(session.endsAt, isNotNull);
      expect(session.frozenAt, isNull);
      expect(session.remaining.inSeconds, closeTo(25 * 60, 2));
    });

    test('freezing stamps the hold and stops the countdown', () async {
      final controller = container.read(focusControllerProvider.notifier)
        ..configure(durationMin: 25);
      await controller.start();
      controller.pause();

      final frozen = container.read(focusControllerProvider);
      expect(frozen.isFrozen, isTrue);
      expect(frozen.frozenAt, isNotNull);

      final first = frozen.remaining;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Same session, later wall clock, same answer.
      expect(container.read(focusControllerProvider).remaining, first);
    });

    test('resuming pushes the end out by the time held', () async {
      final controller = container.read(focusControllerProvider.notifier)
        ..configure(durationMin: 25);
      await controller.start();

      final before = container.read(focusControllerProvider).endsAt!;
      controller.pause();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.resume();

      final after = container.read(focusControllerProvider);
      expect(after.frozenAt, isNull);
      expect(after.status, FocusStatus.running);
      // The end moved forward by roughly the freeze, so the student does not
      // lose the time they were interrupted for.
      final pushed = after.endsAt!.difference(before);
      expect(pushed.inMilliseconds, greaterThanOrEqualTo(45));
      expect(pushed.inMilliseconds, lessThan(2000));
    });

    test('completing clears the freeze stamp', () async {
      final controller = container.read(focusControllerProvider.notifier)
        ..configure(durationMin: 25);
      await controller.start();
      controller.pause();
      await controller.complete(mood: 3);

      final done = container.read(focusControllerProvider);
      expect(done.status, FocusStatus.completed);
      expect(done.frozenAt, isNull);
    });
  });
}
