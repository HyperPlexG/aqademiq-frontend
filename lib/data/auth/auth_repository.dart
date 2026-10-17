import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env/env.dart';
import '../../core/error/failure.dart';
import '../../core/network/dio_client.dart';
import '../models/app_user.dart';

/// Shown when a signup targets an email that already has an account.
///
/// Deliberately names Apple and Google: 40% of real accounts exist only through
/// a social provider, and their owners genuinely do not remember signing up —
/// to them this looks like a brand-new registration that silently fails.
///
/// Note this does confirm the address is registered, which Supabase itself
/// declines to do. That is a considered trade: for a student planner the
/// enumeration risk is slight, and the alternative is a dead end for nearly half
/// the user base. Soften the wording here if that balance ever changes.
const String kAccountAlreadyExists =
    'That email already has an account. Sign in instead — and if you first '
    'joined with Apple or Google, use that button.';

/// Addresses [MockAuthRepository] treats as already registered, so the
/// already-has-an-account path can be exercised without a live backend.
const Set<String> kMockTakenEmails = {'taken@example.com'};

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
  ///
  /// From guest mode this upgrades the guest account in place instead
  /// ([linkGuestToAccount]): a fresh account would leave everything the guest
  /// made behind on the old id (GST-4).
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  });

  /// Confirm the pending OTP (`POST /auth/verify-otp`) → authenticated session.
  Future<void> verifyOtp(String code);

  /// Resend the pending signup/link OTP (`POST /auth/resend-otp`).
  Future<void> resendOtp();

  /// Email a password-reset code.
  ///
  /// Works for an account created with Apple or Google as well: completing the
  /// reset sets a password, which CREATES the email identity those accounts
  /// never had. That is what unsticks the 40% who currently cannot sign in with
  /// an email at all.
  Future<void> sendPasswordReset(String email);

  /// Set a new password on the session a recovery OTP just established.
  Future<void> setPassword(String password);

  /// True while the pending OTP is a password recovery rather than a signup, so
  /// the verify screen knows to ask for a new password instead of onboarding.
  bool get isRecoveryPending;

  /// Google Sign-In — exchange the provider **ID token** for a Supabase session
  /// via `signInWithIdToken`. [nonce] is the **raw** nonce whose SHA-256 was
  /// handed to Google's SDK; on iOS the token embeds that nonce and Supabase
  /// needs the raw value to validate it (Android passes `null`).
  Future<AppUser> signInWithGoogle(String idToken, {String? nonce});

  /// Apple Sign-In — exchange the Apple identity token for a Supabase session
  /// via `signInWithIdToken`. [nonce] is the **raw** nonce whose SHA-256 was
  /// sent to Apple; Supabase needs the raw value to validate the token.
  Future<AppUser> signInWithApple({
    required String identityToken,
    String? nonce,
    String? fullName,
  });

  /// "Save progress": attach email/password to the guest account. Issues an
  /// OTP; finish with [verifyOtp]. Data is preserved under the same user id.
  Future<AppUser> linkGuestToAccount({
    required String email,
    required String password,
  });

  /// Whether the code being waited for upgrades a guest — which decides where
  /// the verify screen goes next: a guest who already set up the app goes back
  /// into it, not through onboarding again.
  bool get isGuestUpgradePending;

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
    _guestChosen = true;
    _emit(user);
    return user;
  }

  /// Mock users start out as a guest before choosing anything; only someone
  /// who actually picked guest mode is upgraded rather than signed up fresh.
  bool _guestChosen = false;
  bool _upgrading = false;

  @override
  bool get isGuestUpgradePending => _upgrading;

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
    // mock == real (README §7, seam 3). The live path throws for an address that
    // already has an account; a mock that always succeeded would hide the one
    // case worth rehearsing, since it is the failure 40% of real users meet.
    if (kMockTakenEmails.contains(email.trim().toLowerCase())) {
      throw const AuthFailure(message: kAccountAlreadyExists);
    }
    _pendingEmail = email;
    _pendingName = name;
    final current = _user;
    if (_guestChosen && current != null && current.isGuest) {
      _upgrading = true;
      return _delayed(current.copyWith(email: email));
    }
    return _delayed(AppUser(id: '', name: name, email: email));
  }

  @override
  Future<void> verifyOtp(String code) async {
    if (_upgrading) {
      // Same id, now with an address: what the live upgrade does.
      _upgrading = false;
      _guestChosen = false;
      final upgraded = await _delayed(
        (_user ?? _guest).copyWith(email: _pendingEmail, isGuest: false),
      );
      _emit(upgraded);
      return;
    }
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
  Future<void> sendPasswordReset(String email) async {
    _pendingEmail = email;
    _mockRecovery = true;
    await _delayed(null);
  }

  @override
  Future<void> setPassword(String password) async {
    _mockRecovery = false;
    await _delayed(null);
  }

  @override
  bool get isRecoveryPending => _mockRecovery;

  bool _mockRecovery = false;

  @override
  Future<AppUser> signInWithGoogle(String idToken, {String? nonce}) async {
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

  /// A guest's chosen password, held until their email is verified: Supabase
  /// upgrades an anonymous user email first, then password.
  String? _pendingPassword;

  @override
  bool get isGuestUpgradePending => _pendingOtpType == OtpType.emailChange;

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
    // A guest is already an account — an anonymous one, which every task and
    // subject they made belongs to. signUp would create a second account and
    // strand all of that on the first (GST-4); upgrading keeps the same id.
    if (_auth.currentUser?.isAnonymous ?? false) {
      return linkGuestToAccount(email: email, password: password);
    }
    _pendingEmail = email;
    _pendingName = name.trim().isEmpty ? null : name.trim();
    _pendingOtpType = OtpType.signup;
    final res = await _auth.signUp(email: email, password: password, data: {'name': name});
    if (res.session != null) return _require(res.session);

    // Supabase will not say "that email is taken" — that would be a
    // user-enumeration hole — so for an address that already has an account it
    // returns a FAKE success: no session, an empty `identities` list, and no
    // email sent at all.
    //
    // Checking only `session != null` therefore dropped the user on an OTP
    // screen waiting for a code that was never going to arrive, and "Resend"
    // was dead too because there was no pending signup to resend. Measured on
    // production: 18 of 45 real accounts (40%) exist only via Apple or Google,
    // so their owners see a first-time signup that silently goes nowhere.
    //
    // `identities == []` is the exact obfuscated shape. A null `user` means some
    // other failure, so it is deliberately not treated as "already exists".
    final identities = res.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AuthFailure(message: kAccountAlreadyExists);
    }
    return AppUser(id: '', name: name, email: email);
  }

  @override
  Future<void> verifyOtp(String code) async {
    final email = _pendingEmail;
    if (email == null) {
      throw const AuthFailure(message: 'No pending verification. Start again.');
    }
    final res = await _auth.verifyOTP(email: email, token: code, type: _pendingOtpType);
    var session = res.session;
    if (_pendingOtpType == OtpType.emailChange) {
      // A guest upgrade: the address is now theirs, so the password can go on.
      session = await _finishGuestUpgrade() ?? session;
    }
    if (session == null) {
      throw const AuthFailure(message: 'Verification failed. Check the code and try again.');
    }
    var user = await _mapSession(session);
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

  /// Sets the password a guest chose at sign-up, then refreshes the session.
  ///
  /// The refresh matters: the API decides who is a guest from the token's
  /// `is_anonymous` claim, and only a token minted after the upgrade says no.
  ///
  /// A password that fails to save does not undo anything — the email is
  /// verified and the data is theirs — so it is retried once and then let go:
  /// "Forgot password" sets one later. Failing here instead would leave them on
  /// a code screen whose code has already been used.
  Future<Session?> _finishGuestUpgrade() async {
    final password = _pendingPassword;
    _pendingPassword = null;
    _pendingOtpType = OtpType.signup;
    if (password != null && password.isNotEmpty) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await _auth.updateUser(UserAttributes(password: password));
          break;
        } on Object catch (e) {
          debugPrint('guest upgrade: password not saved ($e)');
        }
      }
    }
    try {
      return (await _auth.refreshSession()).session ?? _auth.currentSession;
    } on Object {
      return _auth.currentSession;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _pendingEmail = email;
    // No name to apply afterwards — this is a returning user, not a signup.
    _pendingName = null;
    _pendingOtpType = OtpType.recovery;
    await _auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> setPassword(String password) async {
    await _auth.updateUser(UserAttributes(password: password));
    // Only now is the recovery finished. verifyOtp deliberately leaves the type
    // alone so the verify screen can still tell which flow it is completing.
    _pendingOtpType = OtpType.signup;
  }

  @override
  bool get isRecoveryPending => _pendingOtpType == OtpType.recovery;

  @override
  Future<void> resendOtp() async {
    final email = _pendingEmail;
    if (email == null) return;
    await _auth.resend(type: _pendingOtpType, email: email);
  }

  @override
  Future<AppUser> signInWithGoogle(String idToken, {String? nonce}) async {
    final res = await _signInOrLink(OAuthProvider.google, idToken, nonce);
    return _require(res.session);
  }

  @override
  Future<AppUser> signInWithApple({
    required String identityToken,
    String? nonce,
    String? fullName,
  }) async {
    final res = await _signInOrLink(OAuthProvider.apple, identityToken, nonce);
    return _require(res.session);
  }

  /// A guest who picks Google or Apple keeps what they made: the identity is
  /// linked to the guest account, which makes it a real one with the same id.
  ///
  /// Linking fails when that Google or Apple account already has an Aqademiq
  /// account of its own, or when manual linking is switched off in Supabase.
  /// Either way this falls back to signing in exactly as before — the person
  /// gets their existing account, and the guest data stays where it was.
  Future<AuthResponse> _signInOrLink(
    OAuthProvider provider,
    String idToken,
    String? nonce,
  ) async {
    if (_auth.currentUser?.isAnonymous ?? false) {
      try {
        return await _auth.linkIdentityWithIdToken(
          provider: provider,
          idToken: idToken,
          nonce: nonce,
        );
      } on AuthException catch (e) {
        debugPrint('guest link with ${provider.name} not possible: ${e.message}');
      }
    }
    return _auth.signInWithIdToken(provider: provider, idToken: idToken, nonce: nonce);
  }

  @override
  Future<AppUser> linkGuestToAccount({
    required String email,
    required String password,
  }) async {
    // Email first, on its own: Supabase sends a code to confirm the new address
    // (the "Change email address" template, which must carry {{ .Token }}).
    // The password follows once that is verified — see _finishGuestUpgrade.
    try {
      await _auth.updateUser(UserAttributes(email: email));
    } on AuthException catch (e) {
      if (e.code == 'email_exists' || e.message.contains('already been registered')) {
        throw const AuthFailure(message: kAccountAlreadyExists);
      }
      rethrow;
    }
    _pendingEmail = email;
    // The guest already has a name (or onboarding will ask); the email's
    // local part is not a better one.
    _pendingName = null;
    _pendingPassword = password;
    _pendingOtpType = OtpType.emailChange;
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
