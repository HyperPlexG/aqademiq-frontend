import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/env/env.dart';
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

  /// Native "Sign in with Apple" (iOS/macOS). Generates a nonce, hands its
  /// SHA-256 to Apple, and passes the raw nonce + identity token to Supabase.
  /// Returns `true` on success; a user cancellation returns `false` with no
  /// error state (so the screen shows no snackbar), while real failures do.
  Future<bool> signInWithApple() async {
    state = const AsyncLoading();
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthFailure(
            message: 'Apple sign-in failed — no identity token returned.');
      }
      // Apple only returns the name on the very first authorization.
      final fullName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ')
          .trim();
      await ref.read(authRepositoryProvider).signInWithApple(
            identityToken: idToken,
            nonce: rawNonce,
            fullName: fullName.isEmpty ? null : fullName,
          );
      state = const AsyncData(null);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User backed out of the Apple sheet — not an error worth surfacing.
      if (e.code == AuthorizationErrorCode.canceled) {
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError(AuthFailure(message: e.message), StackTrace.current);
      return false;
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  bool _googleInitialized = false;

  /// Native "Sign in with Google". Uses `google_sign_in` 7.x (`initialize` +
  /// `authenticate`), passing the web/server client ID so the returned ID token
  /// has the audience Supabase's Google provider expects. Cancellation returns
  /// `false` with no error; real failures set the error state.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        final isApple = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS);
        await google.initialize(
          // clientId is an iOS/macOS concept; Android rejects it.
          clientId: isApple && Env.googleIosClientId.isNotEmpty
              ? Env.googleIosClientId
              : null,
          serverClientId: Env.googleServerClientId.isNotEmpty
              ? Env.googleServerClientId
              : null,
        );
        _googleInitialized = true;
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
            message: 'Google sign-in failed — no ID token returned.');
      }
      await ref.read(authRepositoryProvider).signInWithGoogle(idToken);
      state = const AsyncData(null);
      return true;
    } on GoogleSignInException catch (e) {
      // User dismissed the Google sheet — not an error worth surfacing.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError(
          AuthFailure(message: e.description ?? 'Google sign-in failed.'),
          StackTrace.current);
      return false;
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// A cryptographically-random nonce for the Apple ID token exchange.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}
