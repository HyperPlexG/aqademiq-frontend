import 'package:dio/dio.dart';

import 'api_helpers.dart';
import 'mock_latency.dart';

/// A copy of everything the account holds, for the person it belongs to.
///
/// `GET /me/export` existed and worked; the app had no way to reach it (STG-7).
/// The app collects consent and stores the age of minors, and privacy law
/// commonly gives people the right to a copy of their own data — so the control
/// is there rather than left to a support request.
abstract interface class DataExportSource {
  Future<Map<String, dynamic>> export();
}

class MockDataExportSource implements DataExportSource {
  @override
  Future<Map<String, dynamic>> export() => mockDelay(<String, dynamic>{
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': <String, dynamic>{'name': 'You'},
        'semesters': const <Object>[],
        'subjects': const <Object>[],
        'tasks': const <Object>[],
        'mood_entries': const <Object>[],
        'study_tags': const <Object>[],
      });
}

/// Live impl — `/v1/me/export`. The server scopes it to the signed-in account.
class ApiDataExportSource implements DataExportSource {
  ApiDataExportSource(this._dio);
  final Dio _dio;

  @override
  Future<Map<String, dynamic>> export() => _dio.getMap('/me/export');
}
