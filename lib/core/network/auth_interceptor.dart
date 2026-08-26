import 'dart:convert';

import 'package:crypto/crypto.dart';
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
      options.headers['Idempotency-Key'] = _idempotencyKey(options);
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

  String _idempotencyKey(RequestOptions options) =>
      idempotencyKeyFor(options, at: DateTime.now());
}

/// Window within which two identical mutations are treated as one.
///
/// Short on purpose. Long enough to absorb a double-tap or a manual retry after
/// a timeout; short enough that deliberately adding the same 25-minute block
/// twice in a row still creates two.
const kIdempotencyDedupeWindow = Duration(seconds: 5);

/// An `Idempotency-Key` derived from the request itself.
///
/// A fresh random key per attempt made the header decorative: the backend
/// dedupes by key, so two attempts at the *same* write arrived under two
/// different keys and both ran. That is the exact case the header exists for — a
/// request that timed out client-side but succeeded server-side, retried by
/// hand, producing a second task. Hashing method + path + body means the retry
/// presents the key the first attempt already claimed, and the backend replays
/// its stored response instead of writing again.
///
/// The time bucket stops this being *too* sticky: without it the key would be
/// stable forever, and the backend's 24h replay cache would refuse a genuinely
/// repeated action for the rest of the day.
///
/// Known limitation: two taps straddling a bucket boundary land in different
/// buckets and both go through. Widening the window would trade that away for
/// the worse failure — refusing writes the user actually meant — so the boundary
/// case is accepted rather than designed out.
///
/// Top-level rather than a method so it is reachable from a test; the enclosing
/// interceptor touches `Supabase.instance`, which cannot be constructed in a
/// unit test without initialising the whole SDK.
String idempotencyKeyFor(RequestOptions options, {required DateTime at}) {
  final bucket =
      at.millisecondsSinceEpoch ~/ kIdempotencyDedupeWindow.inMilliseconds;
  final body = options.data;
  // Only encode what the server actually receives, and canonicalise it: a Map's
  // iteration order follows insertion, so two structurally identical bodies
  // built in a different order would otherwise hash differently and defeat the
  // dedupe entirely.
  final payload = body == null
      ? ''
      : body is String
          ? body
          : jsonEncode(_canonical(body));
  final query = (options.queryParameters.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)))
      .map((e) => '${e.key}=${e.value}')
      .join('&');
  final material =
      '${options.method.toUpperCase()}\n${options.path}\n$query\n$payload\n$bucket';
  return sha256.convert(utf8.encode(material)).toString().substring(0, 32);
}

/// Recursively sort map keys so ordering cannot change the hash.
Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonical(value[k])};
  }
  if (value is Iterable) return value.map(_canonical).toList();
  return value;
}
