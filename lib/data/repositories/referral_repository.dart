import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/error/failure.dart';
import '../../core/network/api_error.dart';
import '../../core/network/dio_client.dart';

/// Fetches the signed-in user's own referral code. The backend allocates a
/// unique code per user and returns it on `GET /referrals/rewards/balance`
/// (alongside the reward balance), so there's no separate "my code" endpoint.
/// What `GET /referrals/rewards/balance` returns.
class ReferralSummary {
  const ReferralSummary({required this.code, required this.redemptions, required this.balance});

  final String code;

  /// People who finished onboarding with this code.
  final int redemptions;

  /// Reward points: the server credits ten per redemption.
  final int balance;
}

class ReferralRepository {
  ReferralRepository(this._ref);

  final Ref _ref;

  /// The user's own code, how many people signed up with it, and the reward
  /// balance — all three from the one response. The code was the only part
  /// ever shown; the count and balance arrived alongside it and were dropped
  /// (REF-6).
  Future<ReferralSummary> summary() async {
    if (Env.useMocks || !Env.hasSupabase) {
      return const ReferralSummary(code: 'ADA42', redemptions: 2, balance: 20);
    }
    final res = await _ref
        .read(dioProvider)
        .get<Map<String, dynamic>>('/referrals/rewards/balance');
    final body = res.data ?? const <String, dynamic>{};
    return ReferralSummary(
      code: (body['code'] as String?) ?? '',
      redemptions: (body['redemptions'] as num?)?.toInt() ?? 0,
      balance: (body['balance'] as num?)?.toInt() ?? 0,
    );
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
final referralSummaryProvider = FutureProvider<ReferralSummary>(
  (ref) => ref.watch(referralRepositoryProvider).summary(),
);

/// Just the code, for the places that only show or share it.
final referralCodeProvider = FutureProvider<String>(
  (ref) async => (await ref.watch(referralSummaryProvider.future)).code,
);
