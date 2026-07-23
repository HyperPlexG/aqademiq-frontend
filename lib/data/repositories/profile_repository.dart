import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../adapters/adapters.dart';
import '../models/user_profile.dart';
import '../models/user_stats.dart';
import '../sources/profile_source.dart';

class ProfileRepository {
  ProfileRepository(this._source);

  final ProfileSource _source;

  Future<UserStats> stats() async => (await _source.stats()).toModel();

  Future<UserProfile> getProfile() => _source.getProfile();

  Future<void> updateProfile(UserProfile profile) =>
      _source.updateProfile(profile);

  Future<bool> shouldSkipOnboarding() => _source.shouldSkipOnboarding();
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final source = Env.useMocks
      ? MockProfileSource()
      : ApiProfileSource(ref.watch(dioProvider));
  return ProfileRepository(source);
});

final statsProvider = FutureProvider<UserStats>(
  (ref) => ref.watch(profileRepositoryProvider).stats(),
);
