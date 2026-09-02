import 'package:freezed_annotation/freezed_annotation.dart';

import 'mood_log.dart';

part 'user_stats.freezed.dart';

/// Profile/Stats summary (README §6). Note that the focus/task totals are
/// LIFETIME figures from `/v1/me/stats` — see `UserStatsDto`.
@freezed
abstract class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int streakDays,
    @Default(0) int focusMinutesLifetime,
    @Default(0) int tasksCompletedLifetime,
    @Default(0) int totalActiveDays,
    @Default(<MoodLog>[]) List<MoodLog> weekMoods,
  }) = _UserStats;
}
