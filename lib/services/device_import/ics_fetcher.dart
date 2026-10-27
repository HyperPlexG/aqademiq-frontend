import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_link.dart';

/// Thrown when a calendar link cannot be downloaded. [message] is shown as is.
class IcsFetchException implements Exception {
  const IcsFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a calendar link (`webcal://…`, Google's secret iCal address,
/// Outlook's published calendar, a Moodle / Canvas feed). Normalise the link
/// first with `normalizeCalendarLink` (calendar_link.dart).
///
/// Its own bare [Dio] on purpose — never `dioProvider`. That one carries the
/// student's Aqademiq session token, which must not be sent to a third-party
/// calendar host.
class IcsFetcher {
  IcsFetcher([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 25),
                responseType: ResponseType.plain,
                headers: const {'Accept': 'text/calendar, text/plain;q=0.9, */*;q=0.5'},
              ),
            );

  final Dio _dio;

  static const _tooBig = IcsFetchException('That calendar is too big to import in one go.');

  Future<String> fetch(Uri uri) async {
    // Stopped as soon as it passes the limit, rather than after the whole
    // download has arrived.
    final cancel = CancelToken();
    var tooBig = false;
    try {
      final response = await _dio.getUri<String>(
        uri,
        cancelToken: cancel,
        onReceiveProgress: (received, _) {
          if (received > maxCalendarBytes && !tooBig) {
            tooBig = true;
            cancel.cancel('too big');
          }
        },
      );
      return response.data ?? '';
    } on DioException catch (e) {
      if (tooBig) throw _tooBig;
      final status = e.response?.statusCode;
      if (status == 401 || status == 403 || status == 404 || status == 410) {
        throw const IcsFetchException(
          "That link didn't open — it may be private or out of date. Copy a fresh iCal link and try again.",
        );
      }
      throw const IcsFetchException("Couldn't download that calendar. Check the link and your connection.");
    }
  }
}

final icsFetcherProvider = Provider<IcsFetcher>((ref) => IcsFetcher());
