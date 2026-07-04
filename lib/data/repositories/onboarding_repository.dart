import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../sources/api_helpers.dart';

/// The onboarding payload the client submits (contract §12.B). Kept transport-
/// agnostic so the controller doesn't build wire JSON.
class OnboardingSubmission {
  const OnboardingSubmission({
    required this.name,
    required this.educationLevel,
    required this.dailyFocusGoalMin,
    required this.subjects,
    this.referralCode,
    this.workBestTimes,
  });

  final String name;
  final String educationLevel;
  final int dailyFocusGoalMin;
  final List<OnboardingSubjectEntry> subjects;
  final String? referralCode;
  final Object? workBestTimes;
}

class OnboardingSubjectEntry {
  const OnboardingSubjectEntry({
    required this.name,
    required this.colorHex,
    required this.mood,
  });
  final String name;
  final String colorHex;
  final int mood;
}

/// Submits `POST /v1/onboarding/complete` (idempotent). No-op under mocks.
class OnboardingRepository {
  OnboardingRepository(this._dio, {required this.useMocks});
  final Dio _dio;
  final bool useMocks;

  Future<void> complete(OnboardingSubmission s) async {
    if (useMocks) return;
    await _dio.postMap('/onboarding/complete', {
      'name': s.name,
      'education_level': s.educationLevel,
      'daily_focus_goal_min': s.dailyFocusGoalMin,
      if (s.referralCode != null && s.referralCode!.isNotEmpty)
        'referral_code': s.referralCode,
      if (s.workBestTimes != null) 'work_best_times': s.workBestTimes,
      'subjects': [
        for (final subj in s.subjects)
          {
            'name': subj.name,
            'color_hex': subj.colorHex,
            'mood': subj.mood,
          },
      ],
    });
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(dioProvider), useMocks: Env.useMocks);
});
