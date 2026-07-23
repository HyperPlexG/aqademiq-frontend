import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
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
}

final referralRepositoryProvider =
    Provider<ReferralRepository>(ReferralRepository.new);

/// The current user's referral code (empty string until loaded / on failure).
final referralCodeProvider = FutureProvider<String>(
  (ref) => ref.watch(referralRepositoryProvider).myCode(),
);
