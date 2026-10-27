import 'dart:convert';

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
                // Bytes, decoded below the same way a picked file is, so an
                // older Latin-1 feed keeps its accents ("Café").
                responseType: ResponseType.bytes,
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
    final List<int> bytes;
    try {
      final response = await _dio.getUri<List<int>>(
        uri,
        cancelToken: cancel,
        // `total` is the declared length (-1 when the server does not say).
        onReceiveProgress: (received, total) {
          if ((received > maxCalendarBytes || total > maxCalendarBytes) && !tooBig) {
            tooBig = true;
            cancel.cancel('too big');
          }
        },
      );
      bytes = response.data ?? const <int>[];
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
    // The chunk that crossed the limit can be the last one, finishing the
    // request before the cancel lands.
    if (tooBig || bytes.length > maxCalendarBytes) throw _tooBig;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}

final icsFetcherProvider = Provider<IcsFetcher>((ref) => IcsFetcher());
