import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../models/import_item.dart';
import '../sources/import_source.dart';
import 'tasks_repository.dart';

/// Calendar import / Reminder import. Picks the source via [Env.useMocks]
/// (seam 3); widgets reach it through the import session provider only.
class ImportRepository {
  ImportRepository(this._source);

  final ImportSource _source;

  Future<ImportCheck> check(ImportSourceKind source, List<String> externalIds) {
    if (externalIds.isEmpty) return Future.value(const ImportCheck());
    return _source.check(source, externalIds);
  }

  /// Import [items] in batches, reporting progress after each.
  ///
  /// If a later batch fails, the earlier ones are already tasks. That is
  /// reported as [ImportInterrupted] rather than a plain failure, because the
  /// student needs to know some of it landed — and trying again is safe, since
  /// the server skips what it already has.
  Future<ImportResult> importAll(
    ImportSourceKind source,
    List<ImportItem> items, {
    String? tagId,
    void Function(int done, int total)? onProgress,
  }) async {
    var imported = 0;
    var skipped = 0;
    for (var i = 0; i < items.length; i += importBatchSize) {
      final end = math.min(i + importBatchSize, items.length);
      try {
        final r = await _source.importBatch(source, items.sublist(i, end), tagId: tagId);
        imported += r.imported;
        skipped += r.skipped;
      } on Object catch (e) {
        if (imported > 0) throw ImportInterrupted(imported: imported, cause: e);
        rethrow;
      }
      onProgress?.call(end, items.length);
    }
    return ImportResult(imported: imported, skipped: skipped);
  }
}

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  final source = Env.useMocks
      ? MockImportSource(ref.watch(tasksRepositoryProvider))
      : ApiImportSource(ref.watch(dioProvider));
  return ImportRepository(source);
});
