import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env/env.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/profile_repository.dart';

/// Single source of truth for the editable profile — Settings → Profile, the
/// Settings hub header, and the Stats header all read this, so an edit reflects
/// everywhere. In mock mode it's the demo seed; live, it loads from `GET /profile`
/// (seeded from the signed-in user until that resolves).
class ProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    if (Env.useMocks) {
      return const UserProfile(
        name: 'Ridhwan Ahamed',
        email: 'f20230375@dubai.bits-pilani.ac.in',
        gender: 'Prefer not to say',
        university: 'BITS Dubai',
        program: 'CS · Undergrad',
      );
    }
    // Live: seed from the signed-in user, then load the full profile.
    final user = ref.read(authStateProvider).value;
    unawaited(_load());
    return UserProfile(name: user?.name ?? '', email: user?.email ?? '');
  }

  Future<void> _load() async {
    try {
      state = await ref.read(profileRepositoryProvider).getProfile();
    } on Object {
      // Keep the seeded value on failure (offline / transient error).
    }
  }

  void updateName(String value) => state = state.copyWith(name: value);
  void updateEmail(String value) => state = state.copyWith(email: value);
  void updateGender(String value) => state = state.copyWith(gender: value);
  void updateDateOfBirth(DateTime value) => state = state.copyWith(dateOfBirth: value);
  void updateHealth(String value) => state = state.copyWith(health: value);
  void updateUniversity(String value) => state = state.copyWith(university: value);
  void updateProgram(String value) => state = state.copyWith(program: value);
}

final profileControllerProvider =
    NotifierProvider<ProfileController, UserProfile>(ProfileController.new);
