import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
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
    // `endsAt` is anchored to the local clock rather than the server's
    // `startedAt`: the 1s timer below also starts now, and the ambient surfaces
    // count down from `endsAt` while the app counts `elapsedSec` up. Anchoring
    // both to the same instant is what stops the two clocks drifting apart.
    final now = DateTime.now();
    state = session.copyWith(
      status: FocusStatus.running,
      elapsedSec: 0,
      startedAt: session.startedAt ?? now,
      endsAt: now.add(Duration(minutes: session.durationMin)),
      frozenAt: null,
    );
    _startTimer();
  }

  void pause() {
    _timer?.cancel();
    // Stamping the freeze instant is what lets `resume` tell held time from
    // spent time; `endsAt` is deliberately left stale until then.
    state = state.copyWith(status: FocusStatus.paused, frozenAt: DateTime.now());
    _persistCheckpoint(paused: true);
  }

  void resume() {
    // Held time is not spent time: push the end out by the whole freeze so the
    // countdown resumes where it stopped rather than where it would have been.
    final frozenAt = state.frozenAt;
    final endsAt = state.endsAt;
    state = state.copyWith(
      status: FocusStatus.running,
      endsAt: (frozenAt != null && endsAt != null)
          ? endsAt.add(DateTime.now().difference(frozenAt))
          : endsAt,
      frozenAt: null,
    );
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

  Future<void> complete({int? mood, int? rating}) async {
    _timer?.cancel();
    state = state.copyWith(
      status: FocusStatus.completed,
      completedAt: DateTime.now(),
      endMood: mood,
      // A finished session is not a held one — leaving the freeze stamp set
      // would make `remaining` keep reporting from the moment it was frozen.
      frozenAt: null,
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
        state = state.copyWith(elapsedSec: total, status: FocusStatus.completed);
      } else {
        state = state.copyWith(elapsedSec: next);
      }
    });
  }
}
