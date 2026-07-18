import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';

/// The onboarding payload the client submits (contract §12.B +
/// `ONBOARDING_CONSENT_AGE_INTEGRATION.md`). Kept transport-agnostic so the
/// controller doesn't build wire JSON.
class OnboardingSubmission {
  const OnboardingSubmission({
    required this.consentGiven,
    required this.age,
    required this.name,
    required this.educationLevel,
    required this.dailyFocusGoalMin,
    required this.subjects,
    this.consentVersion,
    this.referralCode,
    this.workBestTimes,
  });

  /// PDPL data-use consent. Must be `true` or the backend rejects with 403.
  final bool consentGiven;

  /// The privacy/terms version the user accepted (audit trail). Optional but
  /// recommended — omitted from the payload when null/empty.
  final String? consentVersion;

  /// User age. Must be 1–120 and ≥ 18, else the backend rejects (403/400).
  final int age;

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

/// Typed reasons `POST /onboarding/complete` can fail, mapped from the backend's
/// error envelope (`ONBOARDING_CONSENT_AGE_INTEGRATION.md` §4). The onboarding
/// UI switches on these to route/keep the user on the right step. `403` (consent
/// / age) are business-rule rejections switched by message; `400` is schema
/// validation carrying per-field messages.
sealed class OnboardingCompletionException implements Exception {
  const OnboardingCompletionException(this.message);

  /// Surface-ready message (the server's, when it sent one).
  final String message;

  @override
  String toString() => message;
}

/// `403` — `consent_given` missing/false. Keep the user on the consent step.
final class ConsentRequiredException extends OnboardingCompletionException {
  const ConsentRequiredException([
    super.message = 'Please accept the privacy policy to continue.',
  ]);
}

/// `403` — under the legal age (`age < 18`). Block completion.
final class AgeRestrictedException extends OnboardingCompletionException {
  const AgeRestrictedException([
    super.message = 'You must be at least 18 to use Aqademiq.',
  ]);
}

/// `400` — schema validation. [fieldErrors] holds the per-field messages.
final class OnboardingValidationException extends OnboardingCompletionException {
  const OnboardingValidationException(
    super.message, {
    this.fieldErrors = const [],
  });

  final List<String> fieldErrors;
}

/// `401` — missing/invalid bearer token. Re-authenticate.
final class OnboardingAuthException extends OnboardingCompletionException {
  const OnboardingAuthException([
    super.message = 'Your session expired. Please sign in again.',
  ]);
}

/// Network / timeout / anything unanticipated.
final class OnboardingUnknownException extends OnboardingCompletionException {
  const OnboardingUnknownException([
    super.message = 'Something went wrong. Please try again.',
  ]);
}

/// Submits `POST /v1/onboarding/complete` (idempotent — `already_completed` is a
/// success). No-op under mocks. Maps the backend error envelope onto typed
/// [OnboardingCompletionException]s so the UI can react precisely.
class OnboardingRepository {
  OnboardingRepository(this._dio, {required this.useMocks});
  final Dio _dio;
  final bool useMocks;

  Future<void> complete(OnboardingSubmission s) async {
    if (useMocks) return;

    final version = s.consentVersion;
    try {
      // Raw call (not `postMap`) so the error envelope's status_code / message /
      // errors survive for the mapping below — `mapDioError` would collapse the
      // consent-vs-age 403 distinction into a generic AuthFailure.
      await _dio.post<Map<String, dynamic>>(
        '/onboarding/complete',
        data: <String, dynamic>{
          // New PDPL fields. Never send a consent timestamp — the server stamps
          // it at write time (doc §7).
          'consent_given': s.consentGiven,
          if (version != null && version.isNotEmpty) 'consent_version': version,
          'age': s.age,
          // Existing fields (strict body — only documented snake_case keys).
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
        },
      );
    } on DioException catch (e) {
      throw _mapCompletionError(e);
    }
  }

  /// Translate the backend error envelope (doc §4) into a typed exception.
  OnboardingCompletionException _mapCompletionError(DioException e) {
    final data = e.response?.data;
    final body = data is Map ? data : const <dynamic, dynamic>{};
    final status = e.response?.statusCode ?? body['status_code'] as int?;
    final message = body['message'];
    final text = message is String ? message : null;

    switch (status) {
      case 403:
        // Business rule — no `errors` array; disambiguate consent vs age by the
        // server's message (doc §4).
        final lower = (text ?? '').toLowerCase();
        final isAge = lower.contains('age') || lower.contains('18');
        return isAge
            ? AgeRestrictedException(text ?? const AgeRestrictedException().message)
            : ConsentRequiredException(
                text ?? const ConsentRequiredException().message,
              );
      case 400:
        // Schema validation — surface the per-field `errors` list.
        final raw = body['errors'];
        final fields = raw is List
            ? raw.map((x) => x.toString()).toList(growable: false)
            : const <String>[];
        return OnboardingValidationException(
          fields.isNotEmpty ? fields.join('\n') : (text ?? 'Please check your details.'),
          fieldErrors: fields,
        );
      case 401:
        return OnboardingAuthException(text ?? const OnboardingAuthException().message);
      default:
        return OnboardingUnknownException(
          text ?? const OnboardingUnknownException().message,
        );
    }
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(dioProvider), useMocks: Env.useMocks);
});
