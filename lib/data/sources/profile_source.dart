import 'package:dio/dio.dart';

import '../dtos/user_stats_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

abstract interface class ProfileSource {
  Future<UserStatsDto> stats();
}

class MockProfileSource implements ProfileSource {
  @override
  Future<UserStatsDto> stats() => mockDelay(Fixtures.stats());
}

/// Live impl — aggregated `/v1/me/stats` (contract §12.J). `weekMoods` is left
/// empty here; the Stats screen composes weekly moods from `moodWeekProvider`.
class ApiProfileSource implements ProfileSource {
  ApiProfileSource(this._dio);
  final Dio _dio;

  @override
  Future<UserStatsDto> stats() async {
    final j = await _dio.getMap('/me/stats');
    return UserStatsDto(
      streakDays: (j['current_streak'] as num?)?.toInt() ?? 0,
      focusMinutesThisWeek: (j['focus_minutes'] as num?)?.toInt() ?? 0,
      tasksCompletedThisWeek: (j['completed_tasks'] as num?)?.toInt() ?? 0,
    );
  }
}
