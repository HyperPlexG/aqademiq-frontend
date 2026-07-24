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

/// Immutable Ada chat state: the message log + a typing indicator + staged
/// attachments waiting to be sent with the next message.
class AdaChatState {
  const AdaChatState({
    this.messages = const [],
    this.typing = false,
    this.uploading = false,
    this.pendingAttachments = const [],
  });

  final List<AdaMessage> messages;
  final bool typing;

  /// True while a picked file is being uploaded to staging (not yet sent).
  final bool uploading;

  /// Files uploaded and ready to attach on the next explicit Send.
  final List<AdaAttachmentRef> pendingAttachments;

  bool get isEmpty => messages.isEmpty;

  AdaChatState copyWith({
    List<AdaMessage>? messages,
    bool? typing,
    bool? uploading,
    List<AdaAttachmentRef>? pendingAttachments,
  }) =>
      AdaChatState(
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
        uploading: uploading ?? this.uploading,
        pendingAttachments: pendingAttachments ?? this.pendingAttachments,
      );
}

final adaChatProvider =
    NotifierProvider<AdaChatController, AdaChatState>(AdaChatController.new);

class AdaChatController extends Notifier<AdaChatState> {
  @override
  AdaChatState build() => const AdaChatState();

  Future<void> send(String text) async {
    final trimmed = text.trim();
    final attachments = state.pendingAttachments;
    if (trimmed.isEmpty && attachments.isEmpty) return;

    // API requires non-empty text; synthesize a short prompt when the user
    // sends attachments alone.
    final payload = trimmed.isNotEmpty
        ? trimmed
        : attachments.length == 1
            ? "Here's ${attachments.first.name} — can you help me with it?"
            : "Here's ${attachments.map((a) => a.name).join(', ')} — can you help me with them?";

    final userMsg = AdaMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: AdaRole.user,
      text: payload,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      typing: true,
      pendingAttachments: const [],
    );
    try {
      final reply = await ref.read(adaRepositoryProvider).reply(
            payload,
            state.messages,
            attachments: attachments,
          );
      state = state.copyWith(messages: [...state.messages, reply], typing: false);
    } on Object catch (_) {
      // Restore staged files so the user can retry without re-uploading.
      state = state.copyWith(
        typing: false,
        pendingAttachments: attachments,
      );
    }
  }

  void clear() => state = const AdaChatState();

  /// Upload [file] into staging only — does **not** send a chat message.
  Future<void> stageAttachment(XFile file) async {
    state = state.copyWith(uploading: true);
    try {
      final bytes = await file.readAsBytes();
      final attachment = await ref.read(adaRepositoryProvider).uploadAttachment(
            name: file.name,
            mimeType: file.mimeType,
            bytes: bytes,
          );
      state = state.copyWith(
        uploading: false,
        pendingAttachments: [...state.pendingAttachments, attachment],
      );
    } on Object catch (_) {
      state = state.copyWith(uploading: false);
      rethrow;
    }
  }

  /// Drop a staged attachment so it won't be included on the next Send.
  void removePendingAttachment(String key) {
    state = state.copyWith(
      pendingAttachments: [
        for (final a in state.pendingAttachments)
          if (a.key != key) a,
      ],
    );
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
