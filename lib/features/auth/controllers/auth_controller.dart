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

  /// Ceiling on a native SSO round trip.
  ///
  /// The SSO flows below only leave `AsyncLoading` when the platform calls
  /// back. If it never does — an auth sheet that cannot present, which is
  /// exactly what an unconfigured client id produces — this notifier stays
  /// loading forever. Every actionable control on the sign-in screen is gated
  /// on that flag, so the screen stops responding to taps entirely, with no
  /// error, no spinner that ends, and (before this change) no way back.
  ///
  /// That is what App Review hit: submission 7d5244b9, iPad Air 11-inch,
  /// iPadOS 26.6 — "the app became unresponsive when tapping anywhere".
  ///
  /// Long enough for someone to actually type a password into Apple's or
  /// Google's sheet; short enough that a wedged flow heals itself rather than
  /// bricking the screen.
  static const _ssoTimeout = Duration(seconds: 90);

  /// Leave the loading state no matter how the flow ended.
  ///
  /// The individual `catch` blocks below are thorough, but they only run for
  /// errors that reach Dart. A platform channel that never replies produces no
  /// error at all, so correctness here cannot depend on them.
  void _clearIfStillLoading() {
    if (state.isLoading) state = const AsyncData(null);
  }

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
      ).timeout(_ssoTimeout);
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
    } on TimeoutException {
      state = AsyncError(
        const AuthFailure(
            message: "Apple sign-in didn't respond. Please try again."),
        StackTrace.current,
      );
      return false;
    } on Object catch (e, st) {
      state = AsyncError(e, st);
      return false;
    } finally {
      _clearIfStillLoading();
    }
  }

  bool _googleInitialized = false;
  String? _googleRawNonce;

  /// Native "Sign in with Google". Uses `google_sign_in` 7.x (`initialize` +
  /// `authenticate`), passing the web/server client ID so the returned ID token
  /// has the audience Supabase's Google provider expects. Cancellation returns
  /// `false` with no error; real failures set the error state.
  ///
  /// iOS quirk: Apple's Google SDK stamps a `nonce` claim into the ID token, and
  /// Supabase then *requires* the matching raw nonce or rejects the exchange with
  /// "Passed nonce and nonce in id_token should either both exist or not." (This
  /// is why iOS failed while Android — whose Credential Manager token carries no
  /// nonce — worked.) So on Apple platforms we drive the nonce ourselves exactly
  /// like the Apple sign-in flow: hand Google the SHA-256 hash (which it echoes
  /// into the token verbatim) and hand Supabase the raw value (which GoTrue
  /// re-hashes and compares). The nonce is fixed for the app session because
  /// `initialize` runs once; that still binds the token to this client. Android
  /// stays nonce-free, so its already-working path is unchanged.
  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        final isApple = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS);
        String? hashedNonce;
        if (isApple) {
          final rawNonce = _generateNonce();
          _googleRawNonce = rawNonce;
          hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
        }
        await google.initialize(
          // clientId is an iOS/macOS concept; Android rejects it.
          clientId: isApple && Env.googleIosClientId.isNotEmpty
              ? Env.googleIosClientId
              : null,
          serverClientId: Env.googleServerClientId.isNotEmpty
              ? Env.googleServerClientId
              : null,
          nonce: hashedNonce,
        ).timeout(_ssoTimeout);
        _googleInitialized = true;
      }
      final account = await google.authenticate().timeout(_ssoTimeout);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthFailure(
            message: 'Google sign-in failed — no ID token returned.');
      }
      await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(idToken, nonce: _googleRawNonce);
      state = const AsyncData(null);
      return true;
    } on GoogleSignInException catch (e) {
      // Log the real cause: on Android, a SHA-1 / OAuth-client misconfig is
      // surfaced by Credential Manager as `canceled`, so this line disambiguates
      // a genuine user cancel from a broken config.
      debugPrint(
          'Google sign-in failed: code=${e.code.name} description=${e.description} details=${e.details}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError(
          AuthFailure(
              message: (e.description?.isNotEmpty ?? false)
                  ? e.description!
                  : 'Google sign-in failed (${e.code.name}).'),
          StackTrace.current);
      return false;
    } on TimeoutException {
      // The sheet never came back. Most often it never presented at all —
      // see _ssoTimeout and _googleAvailable on the sign-in screen.
      state = AsyncError(
        const AuthFailure(
            message: "Google sign-in didn't respond. Please try again."),
        StackTrace.current,
      );
      return false;
    } on Object catch (e, st) {
      debugPrint('Google sign-in failed (unexpected): $e');
      state = AsyncError(e, st);
      return false;
    } finally {
      _clearIfStillLoading();
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
    try {
      state = await AsyncValue.guard(action);
      return !state.hasError;
    } finally {
      // AsyncValue.guard catches errors, but not a call that never returns.
      _clearIfStillLoading();
    }
  }
}
