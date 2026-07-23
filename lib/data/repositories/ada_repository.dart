import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../adapters/adapters.dart';
import '../models/ada_message.dart';
import '../models/enums.dart';
import '../sources/ada_source.dart';

class AdaRepository {
  AdaRepository(this._source);

  final AdaSource _source;

  Future<AdaMessage> reply(String userText, List<AdaMessage> history) async {
    final dto = await _source.reply(userText, const []);
    return dto.toModel();
  }

  /// Past conversations for the chat-history panel (most-recent first).
  Future<List<AdaConversationDto>> conversations() => _source.conversations();

  /// Load a past conversation's messages and make it the active one.
  Future<List<AdaMessage>> openConversation(String id) async {
    _source.conversationId = id;
    final dtos = await _source.messages(id);
    return dtos.map((d) => d.toModel()).toList(growable: false);
  }

  /// Drop the active conversation so the next reply starts a fresh one.
  void startNewConversation() => _source.conversationId = null;
}

final adaRepositoryProvider = Provider<AdaRepository>((ref) {
  final source =
      Env.useMocks ? MockAdaSource() : ApiAdaSource(ref.watch(dioProvider));
  return AdaRepository(source);
});

/// Immutable Ada chat state: the message log + a typing indicator.
class AdaChatState {
  const AdaChatState({this.messages = const [], this.typing = false});

  final List<AdaMessage> messages;
  final bool typing;

  bool get isEmpty => messages.isEmpty;

  AdaChatState copyWith({List<AdaMessage>? messages, bool? typing}) =>
      AdaChatState(
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
      );
}

final adaChatProvider =
    NotifierProvider<AdaChatController, AdaChatState>(AdaChatController.new);

class AdaChatController extends Notifier<AdaChatState> {
  @override
  AdaChatState build() => const AdaChatState();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final userMsg = AdaMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: AdaRole.user,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      typing: true,
    );
    try {
      final reply = await ref.read(adaRepositoryProvider).reply(trimmed, state.messages);
      state = state.copyWith(messages: [...state.messages, reply], typing: false);
    } on Object catch (_) {
      state = state.copyWith(typing: false);
    }
  }

  void clear() => state = const AdaChatState();

  /// Load a past conversation into the chat view.
  Future<void> openConversation(String id) async {
    state = const AdaChatState(typing: true);
    try {
      final messages = await ref.read(adaRepositoryProvider).openConversation(id);
      state = AdaChatState(messages: messages);
    } on Object {
      state = const AdaChatState();
    }
  }

  /// Start a fresh conversation (clears the view + drops the active id).
  void newConversation() {
    ref.read(adaRepositoryProvider).startNewConversation();
    state = const AdaChatState();
  }
}

/// Past Ada conversations for the history panel.
final adaConversationsProvider = FutureProvider<List<AdaConversationDto>>(
  (ref) => ref.watch(adaRepositoryProvider).conversations(),
);
