import 'package:dio/dio.dart';

import '../models/ada_memory.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// Read/delete access to what Ada remembers (contract §12.P, `/v1/ada/memories`).
///
/// Deliberately no create: memories are written by the agent while it works, not
/// by the app. The client's job is to make what is stored visible and removable.
abstract interface class AdaMemorySource {
  Future<List<AdaMemory>> all();

  /// Forget one. Returns the remaining list so the caller needn't refetch.
  Future<List<AdaMemory>> delete(String id);

  /// Forget everything. Returns how many were removed.
  Future<int> clear();
}

class MockAdaMemorySource implements AdaMemorySource {
  /// Mutable so delete persists for the session (README §7, seam 3: mock == real).
  final List<AdaMemory> _memories = [
    const AdaMemory(
      id: 'mem-1',
      kind: AdaMemoryKind.preference,
      content: 'Prefers deep work in the morning, before 11am',
      source: AdaMemoryOrigin.user,
      confidence: 5,
    ),
    const AdaMemory(
      id: 'mem-2',
      kind: AdaMemoryKind.constraint,
      content: 'Has lab every Tuesday 2–5pm',
      source: AdaMemoryOrigin.user,
      confidence: 4,
    ),
    const AdaMemory(
      id: 'mem-3',
      kind: AdaMemoryKind.pattern,
      content: 'Tends to abandon study sessions longer than 90 minutes',
      source: AdaMemoryOrigin.ada,
    ),
    const AdaMemory(
      id: 'mem-4',
      kind: AdaMemoryKind.goal,
      content: 'Wants a 9.0 CGPA this semester',
      source: AdaMemoryOrigin.user,
      confidence: 4,
    ),
  ];

  @override
  Future<List<AdaMemory>> all() => mockDelay(List.unmodifiable(_memories));

  @override
  Future<List<AdaMemory>> delete(String id) {
    _memories.removeWhere((m) => m.id == id);
    return all();
  }

  @override
  Future<int> clear() {
    final n = _memories.length;
    _memories.clear();
    return mockDelay(n);
  }
}

/// Live impl — `/v1/ada/memories`.
class ApiAdaMemorySource implements AdaMemorySource {
  ApiAdaMemorySource(this._dio);
  final Dio _dio;

  @override
  Future<List<AdaMemory>> all() async {
    final body = await _dio.getMap('/ada/memories');
    return listOf(body, 'memories').map(AdaMemory.fromJson).toList(growable: false);
  }

  @override
  Future<List<AdaMemory>> delete(String id) async {
    await _dio.deleteMap('/ada/memories/$id');
    // Re-read rather than filtering locally: the server is the authority on what
    // is stored, and a delete racing the agent writing a new memory should
    // resolve to whatever the server actually holds.
    return all();
  }

  @override
  Future<int> clear() async {
    final body = await _dio.deleteMap('/ada/memories');
    return (body['deleted'] as num?)?.toInt() ?? 0;
  }
}
