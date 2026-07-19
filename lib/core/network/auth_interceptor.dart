import 'dart:math';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logging_interceptor.dart';

/// Attaches the Supabase access token, auto-adds an `Idempotency-Key` on
/// mutations, and transparently refreshes + retries once on a 401.
///
/// The `supabase_flutter` SDK owns the token lifecycle (persistence + rotation),
/// so this interceptor reads `currentSession` and calls `refreshSession()`.
/// A dedicated bare [Dio] (`_bare`, no interceptors) retries the original
/// request so it can never recurse. Refreshes are single-flight.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required String baseUrl})
      : _bare = Dio(BaseOptions(baseUrl: baseUrl)) {
    _bare.interceptors.add(LoggingInterceptor());
  }

  final Dio _bare;
  final Random _rng = Random.secure();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Set by the auth repository — invoked when a refresh fails (session dead)
  /// so the app can route back to sign-in.
  void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final access = _auth.currentSession?.accessToken;
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    final method = options.method.toUpperCase();
    if (method != 'GET' &&
        method != 'HEAD' &&
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
    final alreadyRetried = err.requestOptions.extra['__retried__'] == true;

    if (status != 401 || alreadyRetried) {
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
      final access = _auth.currentSession?.accessToken;
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
    try {
      final res = await _auth.refreshSession();
      return res.session != null;
    } on Object {
      // Expired / revoked → session is dead.
      try {
        await _auth.signOut();
      } on Object {
        // ignore
      }
      onSessionExpired?.call();
      return false;
    }
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
