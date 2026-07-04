import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/auth/token_store.dart';
import '../../core/env/env.dart';

/// A revision-invalidation signal from the server (contract §8.1). `entity` is
/// an advisory hint; the client should refetch rather than trust it.
class RevisionEvent {
  const RevisionEvent(this.revision, this.entity);
  final int revision;
  final String? entity;
}

/// Socket.IO connection to the `/me/revisions` namespace (contract §8). Emits a
/// [RevisionEvent] on every server-side mutation to the user's data; the app
/// reacts with a `/sync`-style refetch (here: provider invalidation).
class RealtimeRepository {
  RealtimeRepository(this._tokenStore);

  final TokenStore _tokenStore;
  io.Socket? _socket;
  final StreamController<RevisionEvent> _controller =
      StreamController<RevisionEvent>.broadcast();

  Stream<RevisionEvent> get events => _controller.stream;

  void connect() {
    if (_socket != null) return;
    final token = _tokenStore.accessToken;
    if (token == null || token.isEmpty) return;

    _socket = io.io(
      '${Env.socketUrl}/me/revisions',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    )
      ..on('revision', (data) {
        if (data is Map) {
          _controller.add(
            RevisionEvent(
              (data['revision'] as num?)?.toInt() ?? 0,
              data['entity'] as String?,
            ),
          );
        }
      })
      ..connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    unawaited(_controller.close());
  }
}

final realtimeRepositoryProvider = Provider<RealtimeRepository>((ref) {
  final repo = RealtimeRepository(ref.watch(tokenStoreProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final revisionEventsProvider = StreamProvider<RevisionEvent>(
  (ref) => ref.watch(realtimeRepositoryProvider).events,
);
