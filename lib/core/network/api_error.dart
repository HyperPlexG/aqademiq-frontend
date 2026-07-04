import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Maps a low-level [DioException] onto the app's typed [Failure] surface
/// (contract §6 error model). Api sources call this so widgets stay
/// backend-blind and render errors via `AsyncValue.when`.
Failure mapDioError(Object error, [StackTrace? _]) {
  if (error is Failure) return error;
  if (error is! DioException) {
    return UnknownFailure(cause: error);
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return NetworkFailure(cause: error);
    case DioExceptionType.cancel:
      return NetworkFailure(message: 'Request cancelled.', cause: error);
    case DioExceptionType.badCertificate:
      return NetworkFailure(message: 'Secure connection failed.', cause: error);
    case DioExceptionType.badResponse:
      break;
    case DioExceptionType.unknown:
      return UnknownFailure(cause: error);
  }

  final status = error.response?.statusCode ?? 0;
  final message = _extractMessage(error.response?.data);

  switch (status) {
    case 401:
    case 403:
      return AuthFailure(
        message: message ?? 'Please sign in to continue.',
        cause: error,
      );
    case 404:
      return NotFoundFailure(message: message ?? 'Not found.', cause: error);
    case 400:
    case 409:
    case 422:
      return ServerFailure(
        message ?? 'Request could not be processed.',
        statusCode: status,
        cause: error,
      );
    case 429:
      return ServerFailure(
        message ?? 'Too many requests. Please slow down.',
        statusCode: 429,
        cause: error,
      );
    case 501:
      return ServerFailure(
        message ?? 'This feature is not available yet.',
        statusCode: 501,
        cause: error,
      );
    default:
      return ServerFailure(
        message ?? 'Something went wrong. Please try again.',
        statusCode: status,
        cause: error,
      );
  }
}

/// Pulls a human-readable message out of the backend error body. Handles the
/// standard snake_case shape (`message` as string OR array of validation
/// strings) and the middleware's camelCase 429 shape.
String? _extractMessage(Object? data) {
  if (data is! Map) return null;
  final raw = data['message'] ?? data['error'];
  if (raw is String && raw.isNotEmpty) return raw;
  if (raw is List && raw.isNotEmpty) {
    return raw.map((e) => e.toString()).join('\n');
  }
  return null;
}
