import 'package:dio/dio.dart';

import '../dtos/focus_session_dto.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

abstract interface class FocusSource {
  Future<FocusSessionDto> start(FocusSessionDto session);

  /// Persist progress / pause / resume (contract §8.4: no per-second call).
  Future<FocusSessionDto> checkpoint(
    String id, {
    required int elapsedSec,
    required bool paused,
  });

  Future<FocusSessionDto> complete(String id, {int? mood, int? elapsedSec});
}

class MockFocusSource implements FocusSource {
  @override
  Future<FocusSessionDto> start(FocusSessionDto session) => mockDelay(
        session.copyWith(
          id: 'focus-${DateTime.now().microsecondsSinceEpoch}',
          status: 'running',
          startedAt: DateTime.now(),
        ),
        ms: 250,
      );

  @override
  Future<FocusSessionDto> checkpoint(
    String id, {
    required int elapsedSec,
    required bool paused,
  }) =>
      mockDelay(
        FocusSessionDto(
          id: id,
          durationMin: 0,
          elapsedSec: elapsedSec,
          status: paused ? 'paused' : 'running',
        ),
        ms: 120,
      );

  @override
  Future<FocusSessionDto> complete(String id, {int? mood, int? elapsedSec}) =>
      mockDelay(
        FocusSessionDto(
          id: id,
          durationMin: 0,
          elapsedSec: elapsedSec ?? 0,
          status: 'completed',
          completedAt: DateTime.now(),
          endMood: mood,
        ),
        ms: 250,
      );
}

/// Live impl — `/v1/focus-sessions` (contract §12.G). The timer ticks
/// client-side; this persists checkpoints and finalizes the session.
class ApiFocusSource implements FocusSource {
  ApiFocusSource(this._dio);
  final Dio _dio;

  @override
  Future<FocusSessionDto> start(FocusSessionDto session) async {
    final linkedId = session.taskId;
    final linkedDate =
        (linkedId != null) ? dateFromOccurrenceId(linkedId) : null;
    final body = <String, dynamic>{
      'planned_min': session.durationMin,
      'prism_mode': ?session.prismMode,
      if (linkedId != null && linkedId.isNotEmpty) 'task_id': seriesIdOf(linkedId),
      if (linkedDate != null) 'task_date': ymd(linkedDate),
    };
    return _toDto(await _dio.postMap('/focus-sessions', body));
  }

  @override
  Future<FocusSessionDto> checkpoint(
    String id, {
    required int elapsedSec,
    required bool paused,
  }) async {
    final json = await _dio.patchMap('/focus-sessions/$id', {
      'elapsed_sec': elapsedSec,
      'status': paused ? 'PAUSED' : 'RUNNING',
    });
    return _toDto(json);
  }

  @override
  Future<FocusSessionDto> complete(
    String id, {
    int? mood,
    int? elapsedSec,
  }) async {
    final json = await _dio.postMap('/focus-sessions/$id/complete', {
      'mood_index': ?mood,
      'elapsed_sec': ?elapsedSec,
    });
    return _toDto(json);
  }

  FocusSessionDto _toDto(Map<String, dynamic> j) {
    final taskId = j['task_id'] as String?;
    final taskDate = j['task_date'] as String?;
    final linked = (taskId != null && taskDate != null) ? '$taskId@$taskDate' : taskId;
    return FocusSessionDto(
      id: j['id'] as String? ?? '',
      durationMin: (j['planned_min'] as num?)?.toInt() ?? 0,
      taskId: linked,
      prismMode: j['prism_mode'] as String?,
      elapsedSec: (j['elapsed_sec'] as num?)?.toInt() ?? 0,
      status: _statusToDto(j['status'] as String?),
      startedAt: parseDateTime(j['created_at']),
      endMood: (j['mood_index'] as num?)?.toInt(),
    );
  }

  String _statusToDto(String? wire) => switch (wire) {
        'RUNNING' => 'running',
        'PAUSED' => 'paused',
        'COMPLETE' => 'completed',
        _ => 'idle',
      };
}
