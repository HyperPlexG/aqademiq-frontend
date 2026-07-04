import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/token_store.dart';
import '../../core/env/env.dart';
import '../../core/error/failure.dart';
import '../../core/network/api_error.dart';
import '../../core/network/dio_client.dart';
import '../models/app_user.dart';

/// Auth behind an interface (README §7, seam 4).
///
/// ⚠️ Contract §3 / mismatch 1: authentication is the backend's **own RS256 JWT
/// system**, NOT Identity Platform / Firebase. [ApiAuthRepository] implements
/// the REST flow (`/auth/guest|signup|verify-otp|signin|refresh|link-guest…`);
/// [MockAuthRepository] keeps the same surface for `Env.useMocks`.
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

  /// Apple Sign-In — post the identity token (`POST /auth/sso/apple`).
  Future<AppUser> signInWithApple({
    required String identityToken,
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
  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Live — REST JWT (contract §3). Persists tokens; drives the Dio interceptor.
// ---------------------------------------------------------------------------

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._tokens) {
    _controller = StreamController<AppUser?>.broadcast(
      onListen: () => _controller.add(_user),
    );
    unawaited(_bootstrap());
  }

  final Dio _dio;
  final TokenStore _tokens;

  late final StreamController<AppUser?> _controller;
  AppUser? _user;
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
    if (!_controller.isClosed) _controller.add(user);
  }

  /// Called by the interceptor when a refresh fails — session is dead.
  void handleSessionExpired() => _emit(null);

  /// On boot: if we hold tokens, reconstruct the user from the JWT + profile.
  Future<void> _bootstrap() async {
    await _tokens.load();
    if (!_tokens.hasSession) {
      _emit(null);
      return;
    }
    final claims = _decodeJwt(_tokens.accessToken!);
    final id = claims?['sub'] as String? ?? '';
    final isGuest = claims?['is_guest'] as bool? ?? true;
    // Enrich with profile (name/email) — best effort.
    try {
      final res = await _dio.get<Map<String, dynamic>>('/profile');
      final p = res.data ?? const {};
      _emit(AppUser(
        id: id,
        name: (p['name'] as String?)?.trim().isNotEmpty ?? false ? p['name'] as String : 'You',
        email: p['email'] as String?,
        isGuest: (p['is_guest'] as bool?) ?? isGuest,
      ));
    } on Object {
      _emit(AppUser(id: id, name: isGuest ? 'Guest' : 'You', isGuest: isGuest));
    }
  }

  /// Parse a `{access_token, refresh_token, user}` login body; persist + emit.
  Future<AppUser> _consumeTokenPair(Map<String, dynamic> data) async {
    final access = data['access_token'] as String;
    final refresh = data['refresh_token'] as String;
    await _tokens.save(AuthTokens(accessToken: access, refreshToken: refresh));
    final u = (data['user'] as Map?)?.cast<String, dynamic>();
    final claims = _decodeJwt(access);
    final user = AppUser(
      id: (u?['id'] as String?) ?? (claims?['sub'] as String? ?? ''),
      name: _pendingName ??
          (u?['email'] as String?)?.split('@').first ??
          ((u?['is_guest'] as bool? ?? false) ? 'Guest' : 'You'),
      email: u?['email'] as String?,
      isGuest: (u?['is_guest'] as bool?) ?? (claims?['is_guest'] as bool? ?? false),
    );
    _emit(user);
    return user;
  }

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      return res.data ?? const {};
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }

  @override
  Future<AppUser> signInAnonymously() async =>
      _consumeTokenPair(await _post('/auth/guest'));

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _consumeTokenPair(
        await _post('/auth/signin', {'email': email, 'password': password}),
      );

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _pendingEmail = email;
    _pendingName = name.trim().isEmpty ? null : name.trim();
    await _post('/auth/signup', {'email': email, 'password': password});
    return AppUser(id: '', name: name, email: email);
  }

  @override
  Future<void> verifyOtp(String code) async {
    final email = _pendingEmail;
    if (email == null) {
      throw const AuthFailure(message: 'No pending verification. Start again.');
    }
    final data = await _post('/auth/verify-otp', {'email': email, 'code': code});
    final user = await _consumeTokenPair(data);
    // Persist the collected name onto the profile if we have one.
    if (_pendingName != null && _pendingName!.isNotEmpty) {
      try {
        await _dio.patch<Map<String, dynamic>>('/profile', data: {'name': _pendingName});
        _emit(user.copyWith(name: _pendingName!));
      } on Object {
        // Non-fatal.
      }
    }
    _pendingName = null;
  }

  @override
  Future<void> resendOtp() async {
    final email = _pendingEmail;
    if (email == null) return;
    await _post('/auth/resend-otp', {'email': email});
  }

  @override
  Future<AppUser> signInWithGoogle(String idToken) async =>
      _consumeTokenPair(await _post('/auth/sso/google', {'id_token': idToken}));

  @override
  Future<AppUser> signInWithApple({
    required String identityToken,
    String? fullName,
  }) async =>
      _consumeTokenPair(await _post('/auth/sso/apple', {
        'identity_token': identityToken,
        'full_name': ?fullName,
      }));

  @override
  Future<AppUser> linkGuestToAccount({
    required String email,
    required String password,
  }) async {
    _pendingEmail = email;
    await _post('/auth/link-guest', {'email': email, 'password': password});
    // Still a guest until verifyOtp completes; reflect the pending email.
    final current = _user ?? const AppUser(id: '', name: 'Guest');
    return current.copyWith(email: email);
  }

  @override
  Future<void> signOut() async {
    try {
      await _post('/auth/signout');
    } on Object {
      // Ignore — we clear locally regardless.
    }
    await _tokens.clear();
    _emit(null);
  }

  @override
  void dispose() => _controller.close();
}

Map<String, dynamic>? _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
  switch (payload.length % 4) {
    case 2:
      payload += '==';
    case 3:
      payload += '=';
  }
  try {
    return jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
  } on Object {
    return null;
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
  final repo = ApiAuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStoreProvider),
  );
  // Wire the interceptor's session-expiry hook to sign the user out.
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
