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

  void updateName(String value) => _apply(state.copyWith(name: value));
  void updateEmail(String value) => _apply(state.copyWith(email: value));
  void updateGender(String value) => _apply(state.copyWith(gender: value));
  void updateDateOfBirth(DateTime value) =>
      _apply(state.copyWith(dateOfBirth: value));
  void updateHealth(String value) => _apply(state.copyWith(health: value));
  void updateUniversity(String value) =>
      _apply(state.copyWith(university: value));
  void updateProgram(String value) => _apply(state.copyWith(program: value));
  void updateAvatarIndex(int value) =>
      _apply(state.copyWith(avatarIndex: value));

  /// Update local state immediately, then persist to the backend (best-effort;
  /// live only). Email is sent as local-only — the server ignores it here.
  void _apply(UserProfile next) {
    state = next;
    if (!Env.useMocks && Env.hasSupabase) {
      unawaited(_persist(next));
    }
  }

  Future<void> _persist(UserProfile profile) async {
    try {
      await ref.read(profileRepositoryProvider).updateProfile(profile);
    } on Object {
      // Best-effort — keep the local edit even if the write fails.
    }
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, UserProfile>(ProfileController.new);
