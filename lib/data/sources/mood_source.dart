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
    return listOf(body, 'days')
        .where((d) => d['mood_index'] != null)
        .map((d) => _toDto(d, phase: 'adhoc'))
        .toList(growable: false);
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
