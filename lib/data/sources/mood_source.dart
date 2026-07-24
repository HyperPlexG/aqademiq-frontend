import 'package:dio/dio.dart';

import '../dtos/mood_log_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

abstract interface class MoodSource {
  Future<List<MoodLogDto>> week();
  Future<MoodLogDto> log(MoodLogDto entry);
}

class MockMoodSource implements MoodSource {
  final List<MoodLogDto> _logs = [...Fixtures.weekMoods];

  @override
  Future<List<MoodLogDto>> week() =>
      mockDelay(List<MoodLogDto>.unmodifiable(_logs));

  @override
  Future<MoodLogDto> log(MoodLogDto entry) async {
    final created = entry.id.isEmpty
        ? entry.copyWith(id: 'mood-${DateTime.now().microsecondsSinceEpoch}')
        : entry;
    // Upsert by calendar day + phase so edits replace rather than duplicate.
    _logs.removeWhere(
      (l) =>
          l.phase == created.phase &&
          l.date.year == created.date.year &&
          l.date.month == created.date.month &&
          l.date.day == created.date.day,
    );
    _logs.add(created);
    return mockDelay(created);
  }
}

/// Live impl — `/v1/mood-entries` (contract §12.H). The backend keys entries by
/// date (no id); morning/ad-hoc logs `mood_index`, evening writes `reflection`.
class ApiMoodSource implements MoodSource {
  ApiMoodSource(this._dio);
  final Dio _dio;

  @override
  Future<List<MoodLogDto>> week() async {
    final body = await _dio.getMap('/mood-entries/week');
    final out = <MoodLogDto>[];
    for (final d in listOf(body, 'days')) {
      final date = parseDateTime(d['date']) ?? DateTime.now();
      final mi = d['mood_index'];
      if (mi is num) {
        out.add(MoodLogDto(
          id: 'mood-${d['date']}-morning',
          date: date,
          phase: 'morning',
          mood: mi.toInt(),
          note: d['intention'] as String?,
        ));
      }
      // Evening reflection — surfaced so the Stats "daily reflections" list can
      // render it. Without this the reflection text never reaches the app.
      final reflection = d['reflection'];
      if (reflection is String && reflection.trim().isNotEmpty) {
        out.add(MoodLogDto(
          id: 'mood-${d['date']}-evening',
          date: date,
          phase: 'evening',
          mood: mi is num ? mi.toInt() : 3,
          note: reflection,
        ));
      }
    }
    return out.toList(growable: false);
  }

  @override
  Future<MoodLogDto> log(MoodLogDto entry) async {
    final date = ymd(entry.date);
    if (entry.phase == 'evening') {
      final json = await _dio.postMap(
        '/mood-entries/$date/reflection',
        {'reflection': entry.note ?? ''},
      );
      return _toDto(json, phase: entry.phase, fallbackMood: entry.mood);
    }
    final json = await _dio.postMap('/mood-entries', {
      'date': date,
      'mood_index': entry.mood,
      if (entry.note != null) 'intention': entry.note,
    });
    return _toDto(json, phase: entry.phase, fallbackMood: entry.mood);
  }

  MoodLogDto _toDto(
    Map<String, dynamic> j, {
    required String phase,
    int? fallbackMood,
  }) {
    final date = parseDateTime(j['date']) ?? DateTime.now();
    return MoodLogDto(
      id: j['date'] as String? ?? ymd(date),
      date: date,
      phase: phase,
      mood: (j['mood_index'] as num?)?.toInt() ?? fallbackMood ?? 0,
      note: j['reflection'] as String? ?? j['intention'] as String?,
    );
  }
}
