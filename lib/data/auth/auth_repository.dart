import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env/env.dart';
import '../../core/error/failure.dart';
import '../../core/network/dio_client.dart';
import '../models/app_user.dart';

/// Auth behind an interface (README §7, seam 4).
///
/// ⚠️ Contract §3 / mismatch 1: authentication is the backend's **own RS256 JWT
/// system**, NOT Identity Platform / Firebase. [ApiAuthRepository] implements
/// the REST flow (`/auth/guest|signup|verify-otp|signin|refresh|link-guest…`);
/// [MockAuthRepository] keeps the same surface for `Env.useMocks`.
///
/// ⚠️ Token-terminology reconciliation: the feature integration docs
/// (`FEEDBACK_BOARD_INTEGRATION.md`, `ONBOARDING_CONSENT_AGE_INTEGRATION.md`)
/// call the bearer token a `supabase_access_token`, and README §8 calls it an
/// "Identity Platform ID token". These are the **same token** as far as the
/// client is concerned: the `access_token` returned by `/v1/auth/*`, which
/// `openapi.json` documents as a plain `bearer` (JWT) security scheme. Whatever
/// the server uses internally (Supabase, Identity Platform, its own signer) is
/// invisible here — the app just attaches `Authorization: Bearer <access_token>`
/// via the `AuthInterceptor` on every request (reads included). No client change is
/// required to satisfy those docs; the wording differs, the mechanism does not.
abstract interface class AuthRepository {
  /// Emits the current user (or `null` when signed out).
  Stream<AppUser?> authState();

  AppUser? get currentUser;

  /// The email awaiting OTP verification (signup / link-guest), if any.
  String? get pendingEmail;

  /// Guest session — `POST /auth/guest`.
  Future<AppUser> signInAnonymously();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Start email registration (`POST /auth/signup`). Does NOT sign in — the
  /// backend issues a 6-digit OTP; complete with [verifyOtp]. The pending email
  /// is remembered so [verifyOtp] needs only the code.
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Confirm the pending OTP (`POST /auth/verify-otp`) → authenticated session.
  Future<void> verifyOtp(String code);

  /// Resend the pending signup/link OTP (`POST /auth/resend-otp`).
  Future<void> resendOtp();

  /// Google Sign-In — post the provider **ID token** (`POST /auth/sso/google`).
  Future<AppUser> signInWithGoogle(String idToken);

  /// Apple Sign-In — exchange the Apple identity token for a Supabase session
  /// via `signInWithIdToken`. [nonce] is the **raw** nonce whose SHA-256 was
  /// sent to Apple; Supabase needs the raw value to validate the token.
  Future<AppUser> signInWithApple({
    required String identityToken,
    String? nonce,
    String? fullName,
  });

  /// "Save progress": attach email/password to the guest account
  /// (`POST /auth/link-guest`). Issues an OTP; finish with [verifyOtp]. Data is
  /// preserved under the same user id.
  Future<AppUser> linkGuestToAccount({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Permanently delete the account (`DELETE /profile/account`), then sign out.
  Future<void> deleteAccount();

  void dispose();
}

// ---------------------------------------------------------------------------
// Mock — in-memory, starts as a guest (README §1). Unchanged behaviorally.
// ---------------------------------------------------------------------------

class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    _controller = StreamController<AppUser?>.broadcast(
      onListen: () => _controller.add(_user),
    );
  }

  static const _guest = AppUser(id: 'guest-local', name: 'Guest');

  late final StreamController<AppUser?> _controller;
  AppUser? _user = _guest;
  String? _pendingEmail;
  String? _pendingName;

  @override
  AppUser? get currentUser => _user;

  @override
  String? get pendingEmail => _pendingEmail;

  @override
  Stream<AppUser?> authState() => _controller.stream;

  void _emit(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  Future<T> _delayed<T>(T value) =>
      Future<T>.delayed(const Duration(milliseconds: 350), () => value);

  @override
  Future<AppUser> signInAnonymously() async {
    final user = await _delayed(_guest);
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final user = await _delayed(
      AppUser(id: 'user-${email.hashCode}', name: email.split('@').first, email: email, isGuest: false),
    );
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _pendingEmail = email;
    _pendingName = name;
    return _delayed(AppUser(id: '', name: name, email: email));
  }

  @override
  Future<void> verifyOtp(String code) async {
    final user = await _delayed(
      AppUser(
        id: 'user-${(_pendingEmail ?? '').hashCode}',
        name: _pendingName ?? _pendingEmail?.split('@').first ?? 'You',
        email: _pendingEmail,
        isGuest: false,
      ),
    );
    _emit(user);
  }

  @override
  Future<void> resendOtp() => _delayed(null);

  @override
  Future<AppUser> signInWithGoogle(String idToken) async {
    final user = await _delayed(
      const AppUser(id: 'user-google', name: 'Google User', isGuest: false),
    );
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> signInWithApple({
    required String identityToken,
    String? nonce,
    String? fullName,
  }) async {
    final user = await _delayed(
      AppUser(id: 'user-apple', name: fullName ?? 'Apple User', isGuest: false),
    );
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> linkGuestToAccount({
    required String email,
    required String password,
  }) async {
    _pendingEmail = email;
    final current = _user ?? _guest;
    // Mock flips guest → account immediately (no OTP) to drive the demo flow.
    final linked = await _delayed(current.copyWith(email: email, isGuest: false));
    _emit(linked);
    return linked;
  }

  @override
  Future<void> signOut() async {
    await _delayed(null);
    _emit(null);
  }

  @override
  Future<void> deleteAccount() async {
    await _delayed(null);
    _emit(null);
  }

  @override
  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Live — REST JWT (contract §3). Persists tokens; drives the Dio interceptor.
// ---------------------------------------------------------------------------

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio) {
    _controller = StreamController<AppUser?>.broadcast();
    // Mirror Supabase auth state into AppUser. `initialSession` fires on launch
    // with the persisted session (or null), so a returning user stays signed in.
    _sub = _auth.onAuthStateChange.listen((state) async {
      final session = state.session;
      if (session == null) {
        _emit(null);
        return;
      }
      final hydrate = state.event != AuthChangeEvent.tokenRefreshed;
      _emit(await _mapSession(session, hydrate: hydrate));
    });
  }

  final Dio _dio;
  late final StreamController<AppUser?> _controller;
  late final StreamSubscription<AuthState> _sub;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  AppUser? _user;
  String? _pendingEmail;
  String? _pendingName;
  OtpType _pendingOtpType = OtpType.signup;

  @override
  AppUser? get currentUser => _user;

  @override
  String? get pendingEmail => _pendingEmail;

  @override
  Stream<AppUser?> authState() => _controller.stream;

  void _emit(AppUser? user) {
    _user = user;
    if (!_controller.isClosed) _controller.add(user);
  }

  /// Called by the interceptor when a refresh fails — session is dead.
  void handleSessionExpired() => _emit(null);

  /// Build an [AppUser] from the SDK session, enriching from /profile when asked.
  Future<AppUser> _mapSession(Session session, {bool hydrate = true}) async {
    final u = session.user;
    var user = AppUser(
      id: u.id,
      name: (u.userMetadata?['name'] as String?) ??
          (u.email != null ? u.email!.split('@').first : (u.isAnonymous ? 'Guest' : 'You')),
      email: u.email,
      isGuest: u.isAnonymous,
    );
    if (!hydrate) return user;
    try {
      final res = await _dio.get<Map<String, dynamic>>('/profile');
      final p = res.data ?? const {};
      final name = p['name'] as String?;
      user = user.copyWith(
        name: (name != null && name.trim().isNotEmpty) ? name : user.name,
        email: (p['email'] as String?) ?? user.email,
        isGuest: (p['is_guest'] as bool?) ?? user.isGuest,
      );
    } on Object {
      // best-effort profile hydration
    }
    return user;
  }

  Future<AppUser> _require(Session? session, {bool hydrate = true}) async {
    if (session == null) {
      throw const AuthFailure(message: 'Sign-in failed — no session returned.');
    }
    final user = await _mapSession(session, hydrate: hydrate);
    _emit(user);
    return user;
  }

  @override
  Future<AppUser> signInAnonymously() async {
    final res = await _auth.signInAnonymously();
    return _require(res.session, hydrate: false);
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _auth.signInWithPassword(email: email, password: password);
    return _require(res.session);
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _pendingEmail = email;
    _pendingName = name.trim().isEmpty ? null : name.trim();
    _pendingOtpType = OtpType.signup;
    final res = await _auth.signUp(email: email, password: password, data: {'name': name});
    if (res.session != null) return _require(res.session);
    return AppUser(id: '', name: name, email: email);
  }

  @override
  Future<void> verifyOtp(String code) async {
    final email = _pendingEmail;
    if (email == null) {
      throw const AuthFailure(message: 'No pending verification. Start again.');
    }
    final res = await _auth.verifyOTP(email: email, token: code, type: _pendingOtpType);
    if (res.session == null) {
      throw const AuthFailure(message: 'Verification failed. Check the code and try again.');
    }
    var user = await _mapSession(res.session!);
    if (_pendingName != null && _pendingName!.isNotEmpty) {
      try {
        await _dio.patch<Map<String, dynamic>>('/profile', data: {'name': _pendingName});
        user = user.copyWith(name: _pendingName!);
      } on Object {
        // Non-fatal.
      }
    }
    _pendingEmail = null;
    _pendingName = null;
    _emit(user);
  }

  @override
  Future<void> resendOtp() async {
    final email = _pendingEmail;
    if (email == null) return;
    await _auth.resend(type: _pendingOtpType, email: email);
  }

  @override
  Future<AppUser> signInWithGoogle(String idToken) async {
    final res = await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    return _require(res.session);
  }

  @override
  Future<AppUser> signInWithApple({
    required String identityToken,
    String? nonce,
    String? fullName,
  }) async {
    final res = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: identityToken,
      nonce: nonce,
    );
    return _require(res.session);
  }

  @override
  Future<AppUser> linkGuestToAccount({
    required String email,
    required String password,
  }) async {
    await _auth.updateUser(UserAttributes(email: email, password: password));
    _pendingEmail = email;
    _pendingOtpType = OtpType.email;
    final current = _user ?? const AppUser(id: '', name: 'Guest');
    return current.copyWith(email: email);
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on Object {
      // Ignore — the state stream emits null on SIGNED_OUT regardless.
    }
    _emit(null);
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _dio.delete<void>('/profile/account');
    } on Object {
      // Even if the server call fails, still sign out locally below.
    }
    await signOut();
  }

  @override
  void dispose() {
    unawaited(_sub.cancel());
    unawaited(_controller.close());
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useMocks) {
    final repo = MockAuthRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  final repo = ApiAuthRepository(ref.watch(dioProvider));
  ref.watch(authInterceptorProvider).onSessionExpired = repo.handleSessionExpired;
  ref.onDispose(repo.dispose);
  return repo;
});

/// Current user as an `AsyncValue` (loading / data / error for free).
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authState(),
);

/// Whether the active session is a guest — gates Ada / Stats / Save-progress.
final isGuestProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user?.isGuest ?? true;
});
