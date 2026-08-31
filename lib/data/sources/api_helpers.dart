import 'package:dio/dio.dart';

import '../../core/network/api_error.dart';

/// Shared helpers for the live `ApiXxxSource`s: typed Dio calls that map every
/// failure onto the app's `Failure` surface, plus the date/id encodings the
/// backend expects (contract §2, §12).

extension DioJson on Dio {
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final r = await get<Map<String, dynamic>>(path, queryParameters: query);
      return r.data ?? const {};
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }

  /// [options] overrides per-request Dio settings — in practice the receive
  /// timeout, for the few endpoints that legitimately run longer than the
  /// client-wide default.
  Future<Map<String, dynamic>> postMap(
    String path, [
    Object? body,
    Options? options,
  ]) async {
    try {
      final r = await post<Map<String, dynamic>>(path, data: body, options: options);
      return r.data ?? const {};
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }

  Future<Map<String, dynamic>> patchMap(String path, [Object? body]) async {
    try {
      final r = await patch<Map<String, dynamic>>(path, data: body);
      return r.data ?? const {};
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }

  Future<Map<String, dynamic>> putMap(String path, [Object? body]) async {
    try {
      final r = await put<Map<String, dynamic>>(path, data: body);
      return r.data ?? const {};
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }

  Future<Map<String, dynamic>> deleteMap(String path, [Object? body]) async {
    try {
      final r = await delete<Map<String, dynamic>>(path, data: body);
      return r.data ?? const {};
    } on Object catch (e, st) {
      throw mapDioError(e, st);
    }
  }
}

/// Read a list under [key] from a wrapper object, defensively.
List<Map<String, dynamic>> listOf(Map<String, dynamic> body, String key) {
  final raw = body[key];
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

String _p2(int n) => n.toString().padLeft(2, '0');

/// Calendar date → `yyyy-MM-dd` (contract §2: send the date the user views; do
/// NOT convert to UTC).
String ymd(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)}';

/// Wall-clock → naive ISO `yyyy-MM-ddTHH:mm:ss` (contract §2 `scheduled_at`).
String naiveIso(DateTime d) =>
    '${ymd(d)}T${_p2(d.hour)}:${_p2(d.minute)}:${_p2(d.second)}';

/// Parse a naive ISO / date string into a local [DateTime]; null-safe.
///
/// Also accepts API `HH:mm` wall-clock values (tasks `formatTime`). When those
/// are returned, pass [onDate] so the clock can be anchored to the occurrence
/// day — otherwise Planned tasks round-trip as Anytime (`startTime == null`).
DateTime? parseDateTime(Object? v, {DateTime? onDate}) {
  if (v is! String || v.isEmpty) return null;
  final full = DateTime.tryParse(v);
  if (full != null) return full;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null || onDate == null) return null;
  return DateTime(
    onDate.year,
    onDate.month,
    onDate.day,
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
  );
}

/// Extract the `yyyy-MM-dd` from an occurrence id `"{series}@{date}"`.
DateTime? dateFromOccurrenceId(String id) {
  final at = id.lastIndexOf('@');
  if (at < 0) return null;
  return DateTime.tryParse(id.substring(at + 1));
}

/// The series id portion of an occurrence id `"{series}@{date}"`.
String seriesIdOf(String occurrenceId) {
  final at = occurrenceId.lastIndexOf('@');
  return at < 0 ? occurrenceId : occurrenceId.substring(0, at);
}

/// Monday of the week containing [d] (local calendar).
DateTime mondayOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}
