import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An access + refresh token pair (contract §3.1).
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Persists the RS256 access token + opaque refresh token in the platform
/// keychain/keystore (contract §3: "store securely"). Read synchronously-ish by
/// the Dio auth interceptor via an in-memory mirror kept in sync on every write.
class TokenStore {
  TokenStore(this._storage);

  static const _kAccess = 'aqademiq.access_token';
  static const _kRefresh = 'aqademiq.refresh_token';

  final FlutterSecureStorage _storage;

  /// In-memory mirror so the request interceptor can attach the header without
  /// awaiting disk on every call. Hydrated once via [load].
  AuthTokens? _cached;

  AuthTokens? get cached => _cached;
  String? get accessToken => _cached?.accessToken;
  String? get refreshToken => _cached?.refreshToken;
  bool get hasSession => _cached != null;

  /// Load tokens from secure storage into the in-memory mirror (call at boot).
  Future<AuthTokens?> load() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    if (access != null && access.isNotEmpty && refresh != null && refresh.isNotEmpty) {
      _cached = AuthTokens(accessToken: access, refreshToken: refresh);
    } else {
      _cached = null;
    }
    return _cached;
  }

  Future<void> save(AuthTokens tokens) async {
    _cached = tokens;
    await _storage.write(key: _kAccess, value: tokens.accessToken);
    await _storage.write(key: _kRefresh, value: tokens.refreshToken);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureStorageProvider)),
);
