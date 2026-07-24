import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/error/failure.dart';
import '../../core/network/api_error.dart';
import '../../core/network/dio_client.dart';

/// Fetches the signed-in user's own referral code. The backend allocates a
/// unique code per user and returns it on `GET /referrals/rewards/balance`
/// (alongside the reward balance), so there's no separate "my code" endpoint.
class ReferralRepository {
  ReferralRepository(this._ref);

  final Ref _ref;

  Future<String> myCode() async {
    if (Env.useMocks || !Env.hasSupabase) return 'ADA42';
    final res = await _ref
        .read(dioProvider)
        .get<Map<String, dynamic>>('/referrals/rewards/balance');
    return (res.data?['code'] as String?) ?? '';
  }

  /// Soft-check a code during onboarding (no redemption). Throws a typed
  /// [Failure] with the server message on invalid / own-code / network errors.
  Future<void> validateCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (Env.useMocks || !Env.hasSupabase) {
      // Demo codes accepted in mock mode; anything else mirrors live 422.
      if (trimmed == 'ADA42' || trimmed == 'AQAD1') return;
      throw mapDioError(
        DioException(
          requestOptions: RequestOptions(path: '/referrals/validate'),
          response: Response(
            requestOptions: RequestOptions(path: '/referrals/validate'),
            statusCode: 422,
            data: const {'message': 'Invalid referral code'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    }
    try {
      await _ref.read(dioProvider).post<Map<String, dynamic>>(
            '/referrals/validate',
            data: {'code': trimmed},
          );
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }
}

final referralRepositoryProvider =
    Provider<ReferralRepository>(ReferralRepository.new);

/// The current user's referral code (empty string until loaded / on failure).
final referralCodeProvider = FutureProvider<String>(
  (ref) => ref.watch(referralRepositoryProvider).myCode(),
);
