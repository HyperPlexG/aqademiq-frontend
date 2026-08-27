import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../../services/haptics/haptics_service.dart';
import '../adapters/adapters.dart';
import '../dtos/focus_session_dto.dart';
import '../models/enums.dart';
import '../models/focus_session.dart';
import '../sources/focus_source.dart';

class FocusRepository {
  FocusRepository(this._source);

  final FocusSource _source;

  Future<FocusSession> start({
    required int durationMin,
    String? taskId,
    String? prismMode,
  }) async {
    final dto = await _source.start(
      FocusSessionDto(
        id: '',
        durationMin: durationMin,
        taskId: taskId,
        prismMode: prismMode,
      ),
    );
    return dto.toModel();
  }

  Future<FocusSession> checkpoint(
    String id, {
    required int elapsedSec,
    required bool paused,
  }) async =>
      (await _source.checkpoint(id, elapsedSec: elapsedSec, paused: paused))
          .toModel();

  Future<FocusSession> complete(
    String id, {
    int? mood,
    int? elapsedSec,
    int? rating,
  }) async =>
      (await _source.complete(id, mood: mood, elapsedSec: elapsedSec, rating: rating))
          .toModel();
}

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  final source =
      Env.useMocks ? MockFocusSource() : ApiFocusSource(ref.watch(dioProvider));
  return FocusRepository(source);
});

/// Drives a focus session's live state. Per contract §8.4 the timer ticks
/// **client-side** (a local 1s timer) — there is no `focus:tick` server event.
/// Progress is persisted via `PATCH /focus-sessions/:id` checkpoints on
/// pause/resume and finalized with `.../complete`.
final focusControllerProvider =
    NotifierProvider<FocusController, FocusSession>(FocusController.new);

class FocusController extends Notifier<FocusSession> {
  Timer? _timer;

  @override
  FocusSession build() {
    ref.onDispose(() => _timer?.cancel());
    return const FocusSession(id: '', durationMin: 25);
  }

  /// Set the planned duration / link before starting (the fc-set screen).
  void configure({int? durationMin, String? taskId, String? prismMode}) {
    state = state.copyWith(
      durationMin: durationMin ?? state.durationMin,
      taskId: taskId ?? state.taskId,
      prismMode: prismMode ?? state.prismMode,
    );
  }

  Future<void> start() async {
    final session = await ref.read(focusRepositoryProvider).start(
          durationMin: state.durationMin,
          taskId: state.taskId,
          prismMode: state.prismMode,
        );
    // Deliberately ABOVE the state assignment, in the window where the
    // repository has confirmed the session but the status is not yet running.
    //
    // `HapticGovernor.sessionTransitions` does not allow-list focusStarted:
    // spec §4.2 permits only freeze, resume and end during a run, and widening
    // the strictest rule in the document to cover the interior of a session is
    // a worse trade than depending on this ordering. Moving the haptic below
    // the assignment silently deletes it — that is what the governor test
    // "nothing fires while running, except freeze / resume / end" is pinning.
    ref.read(hapticsProvider).focusStarted();
    state = session.copyWith(status: FocusStatus.running, elapsedSec: 0);
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(status: FocusStatus.paused);
    // §5.3 — Freeze is the product's most characteristic interaction and the
    // sharpest thing in Tier 2: a lock engaging.
    ref.read(hapticsProvider).sessionFrozen();
    _persistCheckpoint(paused: true);
  }

  void resume() {
    state = state.copyWith(status: FocusStatus.running);
    // The release of the freeze, softer than the lock that preceded it.
    ref.read(hapticsProvider).sessionResumed();
    _startTimer();
    _persistCheckpoint(paused: false);
  }

  /// Fire-and-forget checkpoint so the server row tracks progress (§8.4).
  void _persistCheckpoint({required bool paused}) {
    if (state.id.isEmpty) return;
    unawaited(
      ref
          .read(focusRepositoryProvider)
          .checkpoint(state.id, elapsedSec: state.elapsedSec, paused: paused)
          .catchError((_) => state),
    );
  }

  /// The one haptic a session's ending earns — fired at most once per session.
  ///
  /// Guide §4.1 / spec §4.3: one user action, one haptic, even when it causes
  /// several state changes internally. Two things make that non-trivial here:
  ///
  ///  * [complete] genuinely runs **twice** on the end-early path — once from
  ///    the timer's End button, then again when the summary screen submits the
  ///    mood and rating (which is safe by design; the server pins `ended_at` to
  ///    the first one);
  ///  * a session that runs to its end never calls [complete] at all — the tick
  ///    in [_startTimer] flips the status, and the summary screen submits later.
  ///
  /// So the trigger is the *transition into completed*, not either call site.
  /// Must be called while the status is still the old one.
  void _resolveOnce({required bool naturally}) {
    if (state.status == FocusStatus.completed) return;
    final haptics = ref.read(hapticsProvider);
    if (naturally) {
      // Tier 1, and the only composite in the app: two beats, second stronger.
      haptics.focusCompleted();
    } else {
      // §5.2 — the melted end. Not punishing; simply not a reward.
      haptics.sessionEndedEarly();
    }
  }

  Future<void> complete({int? mood, int? rating}) async {
    _timer?.cancel();
    _resolveOnce(naturally: state.elapsedSec >= state.durationMin * 60);
    state = state.copyWith(
      status: FocusStatus.completed,
      completedAt: DateTime.now(),
      endMood: mood,
    );
    if (state.id.isNotEmpty) {
      await ref
          .read(focusRepositoryProvider)
          .complete(state.id, mood: mood, elapsedSec: state.elapsedSec, rating: rating);
    }
  }

  void reset() {
    _timer?.cancel();
    state = const FocusSession(id: '', durationMin: 25);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final total = state.durationMin * 60;
      final next = state.elapsedSec + 1;
      if (next >= total) {
        _timer?.cancel();
        // Reached its end naturally — the Tier 1 moment, fired here rather than
        // in complete() because complete() is not on this path.
        _resolveOnce(naturally: true);
        state = state.copyWith(elapsedSec: total, status: FocusStatus.completed);
      } else {
        state = state.copyWith(elapsedSec: next);
      }
    });
  }
}
