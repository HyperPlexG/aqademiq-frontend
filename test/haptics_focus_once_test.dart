// One user action, one haptic — even when it causes several state changes.
//
// This is the regression guide §5 asks for by name, and it guards a trap that
// is live in this codebase rather than hypothetical:
//
//   * `FocusController.complete()` genuinely runs TWICE when a session is ended
//     early. The timer screen's End button calls it, then the summary screen
//     calls it again to submit the mood and rating. That second call is correct
//     and deliberate (the server pins ended_at to the first), so the haptic has
//     to key on the state transition rather than on the method.
//   * A session that runs to its end never calls complete() at all — the
//     periodic tick flips the status, and the summary screen submits later.
//
// A naive `play(HapticMoment.sessionComplete)` at the top of complete() gets both wrong:
// two buzzes for one abandoned session, and none at all for a finished one.

import 'package:aqademiq/data/models/focus_session.dart';
import 'package:aqademiq/data/repositories/focus_repository.dart';
import 'package:aqademiq/data/sources/focus_source.dart';
import 'package:aqademiq/services/haptics/haptics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records moments instead of vibrating.
class _RecordingHaptics extends NoopHapticsService {
  final events = <HapticMoment>[];

  @override
  void play(HapticMoment moment, {int step = 0, int count = 1, String? mode, bool landed = false}) =>
      events.add(moment);
}

class _StubFocusRepo extends FocusRepository {
  _StubFocusRepo() : super(MockFocusSource());

  int completeCalls = 0;

  @override
  Future<FocusSession> start({
    required int durationMin,
    String? taskId,
    String? prismMode,
  }) async =>
      FocusSession(id: 'fs-1', durationMin: durationMin);

  @override
  Future<FocusSession> checkpoint(
    String id, {
    required int elapsedSec,
    required bool paused,
  }) async =>
      const FocusSession(id: 'fs-1', durationMin: 1);

  @override
  Future<FocusSession> complete(
    String id, {
    int? mood,
    int? elapsedSec,
    int? rating,
  }) async {
    completeCalls++;
    return const FocusSession(id: 'fs-1', durationMin: 1);
  }
}

typedef _Env = ({
  ProviderContainer container,
  _RecordingHaptics haptics,
  _StubFocusRepo repo,
});

_Env _setUp() {
  final haptics = _RecordingHaptics();
  final repo = _StubFocusRepo();
  final container = ProviderContainer(
    overrides: [
      focusRepositoryProvider.overrideWithValue(repo),
      hapticsProvider.overrideWithValue(haptics),
    ],
  );
  return (container: container, haptics: haptics, repo: repo);
}

void main() {
  testWidgets('ending early fires one event, not two', (tester) async {
    final env = _setUp();
    addTearDown(env.container.dispose);

    final focus = env.container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 1);
    await focus.start();
    expect(env.haptics.events, [HapticMoment.sessionStart]);

    // The End button.
    await focus.complete();
    // The summary screen, submitting what it collected.
    await focus.complete(mood: 3, rating: 4);

    expect(
      env.repo.completeCalls,
      2,
      reason: 'the second complete() is deliberate and must not be removed',
    );
    expect(
      env.haptics.events,
      [HapticMoment.sessionStart, HapticMoment.sessionEndEarly],
      reason: 'two complete() calls, one resolution, one haptic',
    );
  });

  testWidgets('a session that reaches its end earns the composite once',
      (tester) async {
    final env = _setUp();
    addTearDown(env.container.dispose);
    await tester.pumpWidget(const SizedBox.shrink());

    final focus = env.container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 1);
    await focus.start();

    // Let the client-side tick run the full minute out.
    await tester.pump(const Duration(seconds: 61));

    expect(env.haptics.events, [
      HapticMoment.sessionStart,
      HapticMoment.sessionComplete,
    ]);

    // The summary screen still submits afterwards, and must stay silent.
    await focus.complete(mood: 3, rating: 5);
    expect(env.haptics.events, [
      HapticMoment.sessionStart,
      HapticMoment.sessionComplete,
    ]);
  });

  testWidgets('freeze and resume each speak once', (tester) async {
    final env = _setUp();
    addTearDown(env.container.dispose);

    final focus = env.container.read(focusControllerProvider.notifier)
      ..configure(durationMin: 25);
    await focus.start();
    focus
      ..pause()
      ..resume();

    expect(env.haptics.events, [
      HapticMoment.sessionStart,
      HapticMoment.sessionPause,
      HapticMoment.sessionResume,
    ]);

    // Leave no periodic timer pending at teardown.
    await focus.complete();
  });

  testWidgets('a session with no server row still resolves exactly once',
      (tester) async {
    // complete() no-ops against the repository without an id. The status
    // transition is real regardless, so it is still one event — never two,
    // never none.
    final env = _setUp();
    addTearDown(env.container.dispose);

    final focus = env.container.read(focusControllerProvider.notifier);
    await focus.complete();
    await focus.complete();

    expect(env.repo.completeCalls, 0);
    expect(env.haptics.events, [HapticMoment.sessionEndEarly]);
  });
}
