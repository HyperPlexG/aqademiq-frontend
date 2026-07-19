import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../data/auth/auth_repository.dart';

/// Human-readable message for an auth error, whether it's a Supabase
/// [AuthException] (the SDK's errors), a domain [Failure], or anything else.
String authErrorMessage(Object? error) {
  if (error is AuthException) return error.message;
  if (error is Failure) return error.message;
  return 'Something went wrong. Please try again.';
}

/// Drives the auth actions (guest / sign-in / sign-up / verify). Screens watch
/// its `isLoading` for button spinners and navigate on a `true` result. Backed
/// by the backend's REST JWT flow (contract §3) via `AuthRepository`.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> guest() =>
      _run(() => ref.read(authRepositoryProvider).signInAnonymously());

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
          ));

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(() => ref.read(authRepositoryProvider).signUp(
            name: name,
            email: email,
            password: password,
          ));

  Future<bool> verify(String code) =>
      _run(() => ref.read(authRepositoryProvider).verifyOtp(code));

  /// Resend the pending signup/link OTP.
  Future<bool> resend() =>
      _run(() => ref.read(authRepositoryProvider).resendOtp());

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}
