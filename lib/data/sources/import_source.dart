import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../models/import_item.dart';
import '../models/task.dart';
import '../repositories/tasks_repository.dart';
import 'api_helpers.dart';

/// Data source for Calendar import / Reminder import. The repository picks the
/// impl via `Env.useMocks`; widgets never see this layer.
abstract interface class ImportSource {
  /// Which of [externalIds] are already in the plan, and which were imported
  /// and since deleted (`POST /integrations/import/check`).
  Future<ImportCheck> check(ImportSourceKind source, List<String> externalIds);

  /// Turn one batch (at most [importBatchSize] items) into tasks
  /// (`POST /integrations/import`). Items already in the plan are skipped by
  /// the server, so sending one twice is harmless.
  Future<ImportResult> importBatch(
    ImportSourceKind source,
    List<ImportItem> items, {
    String? tagId,
  });
}

/// Items per request. The server allows 200; 100 keeps each request quick on
/// a slow connection, and the review screen shows progress between them.
const importBatchSize = 100;

/// Ids per check request (the server allows 1000).
const importCheckBatchSize = 500;

/// Mock == real (README seam 3): imports really become tasks in the mock plan,
/// and a second import of the same items is skipped.
class MockImportSource implements ImportSource {
  MockImportSource(this._tasks);

  final TasksRepository _tasks;

  /// `<source>:<external id>` → task id. Static so it survives the provider
  /// being rebuilt, the way a server would.
  static final Map<String, String> _imported = {};

  static String _key(ImportSourceKind source, String externalId) => '${source.wire}:$externalId';

  @override
  Future<ImportCheck> check(ImportSourceKind source, List<String> externalIds) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return ImportCheck(
      existing: {
        for (final id in externalIds)
          if (_imported.containsKey(_key(source, id))) id,
      },
    );
  }

  @override
  Future<ImportResult> importBatch(
    ImportSourceKind source,
    List<ImportItem> items, {
    String? tagId,
  }) async {
    final fresh = <ImportItem>[];
    final seen = <String>{};
    for (final item in items) {
      final key = _key(source, item.externalId);
      if (_imported.containsKey(key) || !seen.add(key)) continue;
      fresh.add(item);
    }
    // Created together: each mock create waits its own latency, and one at a
    // time would make a timetable import take a minute. Ids are given here
    // because MockTasksSource derives one from the clock, which repeats when
    // a whole batch is created in the same microsecond.
    final batch = DateTime.now().microsecondsSinceEpoch;
    final created = await Future.wait([
      for (var i = 0; i < fresh.length; i++)
        _tasks.create(
          Task(
            id: 'import-$batch-$i',
            title: fresh[i].title,
            tagId: tagId ?? '',
            date: fresh[i].date,
            note: fresh[i].note,
            dayPart: fresh[i].dayPart,
            startTime: fresh[i].startTime,
            durationMin: fresh[i].startTime == null ? null : fresh[i].durationMin,
          ),
        ),
    ]);
    for (var i = 0; i < fresh.length; i++) {
      _imported[_key(source, fresh[i].externalId)] = created[i].id;
    }
    return ImportResult(imported: fresh.length, skipped: items.length - fresh.length);
  }
}

/// Live impl — `POST /v1/integrations/import` and `…/import/check`
/// (backend `services/import_plan.ts`).
///
/// Times follow the tasks contract: the wall-clock `HH:mm` the student sees,
/// never converted to UTC.
class ApiImportSource implements ImportSource {
  ApiImportSource(this._dio);

  final Dio _dio;

  @override
  Future<ImportCheck> check(ImportSourceKind source, List<String> externalIds) async {
    final existing = <String>{};
    final removed = <String>{};
    for (var i = 0; i < externalIds.length; i += importCheckBatchSize) {
      final chunk = externalIds.sublist(i, math.min(i + importCheckBatchSize, externalIds.length));
      final body = await _dio.postMap('/integrations/import/check', {
        'source': source.wire,
        'external_ids': chunk,
      });
      existing.addAll(_strings(body['existing']));
      removed.addAll(_strings(body['removed']));
    }
    return ImportCheck(existing: existing, removed: removed);
  }

  @override
  Future<ImportResult> importBatch(
    ImportSourceKind source,
    List<ImportItem> items, {
    String? tagId,
  }) async {
    final body = await _dio.postMap('/integrations/import', {
      'source': source.wire,
      if (tagId != null && tagId.isNotEmpty) 'category': tagId,
      'items': [for (final item in items) _toWire(item)],
    });
    return ImportResult(
      imported: (body['imported'] as num?)?.toInt() ?? 0,
      skipped: (body['skipped'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, Object?> _toWire(ImportItem item) {
    final start = item.startTime;
    final duration = item.durationMin;
    final note = item.note;
    return {
      'external_id': item.externalId,
      'title': item.title,
      'date': ymd(item.date),
      if (start != null) 'start_time': '${_p2(start.hour)}:${_p2(start.minute)}',
      if (start != null && duration != null) 'duration_seconds': duration * 60,
      'part_of_day': item.dayPart.name,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');

  static Iterable<String> _strings(Object? raw) =>
      raw is List ? raw.whereType<String>() : const <String>[];
}
