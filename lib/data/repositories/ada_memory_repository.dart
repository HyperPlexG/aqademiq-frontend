import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../models/ada_memory.dart';
import '../sources/ada_memory_source.dart';

class AdaMemoryRepository {
  AdaMemoryRepository(this._source);
  final AdaMemorySource _source;

  Future<List<AdaMemory>> all() => _source.all();
  Future<List<AdaMemory>> delete(String id) => _source.delete(id);
  Future<int> clear() => _source.clear();
}

final adaMemoryRepositoryProvider = Provider<AdaMemoryRepository>((ref) {
  final source = Env.useMocks
      ? MockAdaMemorySource()
      : ApiAdaMemorySource(ref.watch(dioProvider));
  return AdaMemoryRepository(source);
});

/// What Ada currently remembers, grouped for display by the screen.
///
/// An `AsyncNotifier` rather than a `FutureProvider` because deletion has to
/// update the same state the list is rendering: re-fetching through a plain
/// future provider would flash a spinner over the whole screen every time one
/// row is removed.
final adaMemoriesProvider =
    AsyncNotifierProvider<AdaMemoriesController, List<AdaMemory>>(
  AdaMemoriesController.new,
);

class AdaMemoriesController extends AsyncNotifier<List<AdaMemory>> {
  @override
  Future<List<AdaMemory>> build() => ref.read(adaMemoryRepositoryProvider).all();

  /// Forget one memory.
  ///
  /// Optimistic: the row disappears immediately and is restored if the server
  /// refuses. Deleting a memory is a small, obviously-reversible-by-Ada action,
  /// and making the user watch a spinner to remove something they did not want
  /// stored in the first place reads as reluctance.
  Future<bool> forget(String id) async {
    final previous = state.value ?? const <AdaMemory>[];
    state = AsyncValue.data([
      for (final m in previous)
        if (m.id != id) m,
    ]);
    try {
      final remaining = await ref.read(adaMemoryRepositoryProvider).delete(id);
      state = AsyncValue.data(remaining);
      return true;
    } on Object {
      state = AsyncValue.data(previous);
      return false;
    }
  }

  /// Forget everything. Returns how many were removed, or null on failure.
  Future<int?> clear() async {
    final previous = state.value ?? const <AdaMemory>[];
    state = const AsyncValue.data([]);
    try {
      return await ref.read(adaMemoryRepositoryProvider).clear();
    } on Object {
      state = AsyncValue.data(previous);
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(adaMemoryRepositoryProvider).all(),
    );
  }
}
