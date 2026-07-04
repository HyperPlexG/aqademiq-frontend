import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_store.dart';
import '../env/env.dart';
import 'auth_interceptor.dart';

/// The shared [AuthInterceptor] (holds the single-flight refresh + the
/// session-expired hook the auth repository wires into).
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  return AuthInterceptor(
    tokenStore: ref.watch(tokenStoreProvider),
    baseUrl: Env.apiBaseUrl,
  );
});

/// The shared Dio instance for the NestJS REST API (contract §1, §2).
///
/// - `baseUrl` includes the global `/v1` prefix (from `--dart-define`).
/// - JSON is snake_case in both directions; no case transform is applied.
/// - The [AuthInterceptor] attaches the Bearer token, adds `Idempotency-Key`
///   on mutations, and refreshes-and-retries once on 401.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      // Let the app map non-2xx into typed Failures via mapDioError.
      validateStatus: (code) => code != null && code >= 200 && code < 300,
    ),
  );
  dio.interceptors.add(ref.watch(authInterceptorProvider));
  return dio;
});
