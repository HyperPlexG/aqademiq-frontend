import 'dart:math';

import 'package:dio/dio.dart';

import '../auth/token_store.dart';

/// Attaches the Bearer access token, auto-adds an `Idempotency-Key` on
/// mutations, and transparently refreshes + retries once on a 401
/// (contract §3.2, §4).
///
/// A dedicated bare [Dio] (`_bare`, no interceptors) is used for both the
/// `/auth/refresh` call and the retry of the original request, so refresh can
/// never recurse into this interceptor. Refreshes are single-flight
/// (serialized) to avoid triggering the backend's reuse-detection.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required String baseUrl,
  })  : _tokens = tokenStore,
        _bare = Dio(BaseOptions(baseUrl: baseUrl));

  final TokenStore _tokens;
  final Dio _bare;
  final Random _rng = Random.secure();

  /// Set by the auth repository — invoked when a refresh fails (session dead)
  /// so the app can route back to sign-in.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  bool _isRefreshCall(String path) => path.contains('/auth/refresh');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = _tokens.accessToken;
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    final method = options.method.toUpperCase();
    if (method != 'GET' && method != 'HEAD' &&
        !options.headers.containsKey('Idempotency-Key')) {
      options.headers['Idempotency-Key'] = _idempotencyKey();
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;

    final canRefresh = status == 401 &&
        !alreadyRetried &&
        !_isRefreshCall(path) &&
        (_tokens.refreshToken?.isNotEmpty ?? false);

    if (!canRefresh) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      handler.next(err);
      return;
    }

    try {
      final opts = err.requestOptions;
      opts.extra['__retried__'] = true;
      final access = _tokens.accessToken;
      if (access != null) opts.headers['Authorization'] = 'Bearer $access';
      final response = await _bare.fetch<dynamic>(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Single-flight refresh: concurrent 401s share one refresh call.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _bare.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = res.data;
      final access = data?['access_token'] as String?;
      final newRefresh = data?['refresh_token'] as String?;
      if (access == null || newRefresh == null) {
        await _fail();
        return false;
      }
      await _tokens.save(
        AuthTokens(accessToken: access, refreshToken: newRefresh),
      );
      return true;
    } on DioException {
      // Invalid / reused refresh token → session is dead.
      await _fail();
      return false;
    }
  }

  Future<void> _fail() async {
    await _tokens.clear();
    onSessionExpired?.call();
  }

  String _idempotencyKey() {
    const hex = '0123456789abcdef';
    final b = StringBuffer();
    for (var i = 0; i < 32; i++) {
      b.write(hex[_rng.nextInt(16)]);
      if (i == 7 || i == 11 || i == 15 || i == 19) b.write('-');
    }
    return b.toString();
  }
}
