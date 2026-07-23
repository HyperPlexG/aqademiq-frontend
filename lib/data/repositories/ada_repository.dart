import 'package:file_selector/file_selector.dart';
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

  Future<AdaMessage> reply(
    String userText,
    List<AdaMessage> history, {
    List<AdaAttachmentRef> attachments = const [],
  }) async {
    final dto = await _source.reply(userText, const [], attachments: attachments);
    return dto.toModel();
  }

  /// Presign + upload a file and return the ref to attach to the next message.
  Future<AdaAttachmentRef> uploadAttachment({
    required String name,
    String? mimeType,
    required List<int> bytes,
  }) =>
      _source.upload(name: name, mimeType: mimeType, bytes: bytes);

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

  /// Apply the schedule Ada proposed in [messageId] to the user's plan.
  Future<void> applyPlan(String messageId) => _source.applyPlan(messageId);
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

  /// Upload [file], attach it to a message, and stream Ada's reply.
  Future<void> attachAndSend(XFile file) async {
    final text = "Here's ${file.name} — can you help me with it?";
    final userMsg = AdaMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: AdaRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, userMsg], typing: true);
    try {
      final bytes = await file.readAsBytes();
      final repo = ref.read(adaRepositoryProvider);
      final attachment = await repo.uploadAttachment(
        name: file.name,
        mimeType: file.mimeType,
        bytes: bytes,
      );
      final reply = await repo.reply(
        text,
        state.messages,
        attachments: [attachment],
      );
      state = state.copyWith(messages: [...state.messages, reply], typing: false);
    } on Object catch (_) {
      state = state.copyWith(typing: false);
    }
  }

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

  /// Apply Ada's proposed schedule (from [messageId]) to the plan.
  Future<void> applyPlan(String messageId) =>
      ref.read(adaRepositoryProvider).applyPlan(messageId);
}

/// Past Ada conversations for the history panel.
final adaConversationsProvider = FutureProvider<List<AdaConversationDto>>(
  (ref) => ref.watch(adaRepositoryProvider).conversations(),
);
