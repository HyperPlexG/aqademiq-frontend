import 'package:dio/dio.dart';

import '../dtos/user_stats_dto.dart';
import '../fixtures/fixtures.dart';
import '../models/user_profile.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

const _demoProfile = UserProfile(
  name: 'Ridhwan Ahamed',
  email: 'f20230375@dubai.bits-pilani.ac.in',
  gender: 'Prefer not to say',
  university: 'BITS Dubai',
  program: 'CS · Undergrad',
);

abstract interface class ProfileSource {
  Future<UserStatsDto> stats();

  /// The editable profile (name/email/university/…) from `GET /profile`.
  Future<UserProfile> getProfile();

  /// Persist edited profile fields via `PATCH /profile`. Email is not editable
  /// here (it's an auth flow); `health` has no server field.
  Future<void> updateProfile(UserProfile profile);

  /// Whether the signed-in account can skip onboarding — true if it has already
  /// finished onboarding, or it's a guest ("jump right in"). Used to gate
  /// post-auth routing (app vs. the onboarding flow).
  Future<bool> shouldSkipOnboarding();
}

class MockProfileSource implements ProfileSource {
  @override
  Future<UserStatsDto> stats() => mockDelay(Fixtures.stats());

  @override
  Future<UserProfile> getProfile() => mockDelay(_demoProfile);

  @override
  Future<void> updateProfile(UserProfile profile) => mockDelay(null);

  @override
  Future<bool> shouldSkipOnboarding() => mockDelay(true);
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

  @override
  Future<UserProfile> getProfile() async {
    final j = await _dio.getMap('/profile');
    final dob = j['date_of_birth'] as String?;
    return UserProfile(
      name: (j['name'] as String?)?.trim() ?? '',
      email: (j['email'] as String?) ?? '',
      gender: j['gender'] as String?,
      dateOfBirth: (dob != null && dob.isNotEmpty) ? DateTime.tryParse(dob) : null,
      university: j['university'] as String?,
      program: j['program'] as String?,
      avatarIndex: (j['avatar_index'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> updateProfile(UserProfile p) async {
    await _dio.patch<dynamic>('/profile', data: <String, dynamic>{
      'name': p.name,
      if (p.gender != null) 'gender': p.gender,
      if (p.dateOfBirth != null) 'date_of_birth': _fmtDate(p.dateOfBirth!),
      if (p.university != null) 'university': p.university,
      if (p.program != null) 'program': p.program,
      'avatar_index': p.avatarIndex,
    });
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<bool> shouldSkipOnboarding() async {
    final j = await _dio.getMap('/profile');
    final guest = j['is_guest'] as bool? ?? false;
    final done = j['onboarding_complete'] as bool? ?? false;
    return guest || done;
  }
}
