import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../sources/data_export_source.dart';

class DataExportRepository {
  DataExportRepository(this._source);
  final DataExportSource _source;

  /// The export as readable JSON, indented so it can be opened and read
  /// without a tool.
  Future<String> exportJson() async =>
      const JsonEncoder.withIndent('  ').convert(await _source.export());
}

final dataExportRepositoryProvider = Provider<DataExportRepository>((ref) {
  final source = Env.useMocks
      ? MockDataExportSource()
      : ApiDataExportSource(ref.watch(dioProvider));
  return DataExportRepository(source);
});
