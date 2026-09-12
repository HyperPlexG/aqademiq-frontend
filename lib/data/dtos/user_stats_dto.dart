import 'package:freezed_annotation/freezed_annotation.dart';

import 'mood_log_dto.dart';

part 'user_stats_dto.freezed.dart';
part 'user_stats_dto.g.dart';

@freezed
abstract class UserStatsDto with _$UserStatsDto {
  const factory UserStatsDto({
    @Default(0) int streakDays,
    // These two are LIFETIME totals. `/v1/me/stats` sums every completed task
    // and every focus session a user has ever run; it has no week filter and
    // never had one. They were called `...ThisWeek` here, and the Stats screen
    // showed the result under a "this week" label whenever the real weekly
    // provider was still loading — a lifetime count presented as seven days.
    // Named for what they are so the next person cannot make that mistake.
    @Default(0) int focusMinutesLifetime,
    @Default(0) int tasksCompletedLifetime,
    /// Days the student has ever been on the board. Only ever goes up, and has
    /// nothing to fall short of — which is why it replaced the streak on the
    /// Stats screen.
    @Default(0) int totalActiveDays,
    @Default(<MoodLogDto>[]) List<MoodLogDto> weekMoods,
  }) = _UserStatsDto;

  factory UserStatsDto.fromJson(Map<String, dynamic> json) =>
      _$UserStatsDtoFromJson(json);
}
