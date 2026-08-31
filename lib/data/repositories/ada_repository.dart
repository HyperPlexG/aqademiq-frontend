import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/error/failure.dart';
import '../../core/network/dio_client.dart';
import '../adapters/adapters.dart';
import '../models/ada_action.dart';
import '../models/ada_message.dart';
import '../models/enums.dart';
import '../sources/ada_source.dart';

/// One assistant turn as the UI sees it: the message plus the changes Ada is
/// asking permission to make.
typedef AdaReplyResult = ({AdaMessage message, List<AdaAction> actions});

class AdaRepository {
  AdaRepository(this._source);

  final AdaSource _source;

  Future<AdaReplyResult> reply(
    String userText,
    List<AdaMessage> history, {
    List<AdaAttachmentRef> attachments = const [],
  }) async {
    final turn = await _source.reply(userText, const [], attachments: attachments);
    return (message: turn.message.toModel(), actions: turn.actions);
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

  /// Load a past conversation's messages (with their action cards) and make it
  /// the active one.
  Future<List<AdaReplyResult>> openConversation(String id) async {
    _source.conversationId = id;
    final turns = await _source.messages(id);
    return turns
        .map((t) => (message: t.message.toModel(), actions: t.actions))
        .toList(growable: false);
  }

  /// Drop the active conversation so the next reply starts a fresh one.
  void startNewConversation() => _source.conversationId = null;

  /// Apply the schedule Ada proposed in [messageId] (legacy pre-agent plans).
  Future<void> applyPlan(String messageId) => _source.applyPlan(messageId);

  Future<AdaDecisionResult> approveAction(String actionId) =>
      _source.approveAction(actionId);

  Future<AdaDecisionResult> rejectAction(String actionId) =>
      _source.rejectAction(actionId);

  Future<AdaBulkDecision> decideAll({required bool approve}) =>
      _source.decideAll(approve: approve);
}

final adaRepositoryProvider = Provider<AdaRepository>((ref) {
  final source =
      Env.useMocks ? MockAdaSource() : ApiAdaSource(ref.watch(dioProvider));
  return AdaRepository(source);
});

/// Immutable Ada chat state: the message log + a typing indicator + staged
/// attachments waiting to be sent + the changes awaiting the user's decision.
class AdaChatState {
  const AdaChatState({
    this.messages = const [],
    this.typing = false,
    this.uploading = false,
    this.pendingAttachments = const [],
    this.actionsByMessage = const {},
    this.decidingActionIds = const {},
    this.error,
  });

  final List<AdaMessage> messages;
  final bool typing;

  /// True while a picked file is being uploaded to staging (not yet sent).
  final bool uploading;

  /// Files uploaded and ready to attach on the next explicit Send.
  final List<AdaAttachmentRef> pendingAttachments;

  /// Proposed changes keyed by the assistant message that asked for them.
  final Map<String, List<AdaAction>> actionsByMessage;

  /// Actions with a decision in flight — their card shows a spinner.
  final Set<String> decidingActionIds;

  /// Why the last turn failed, in words meant for the person waiting.
  ///
  /// Null when nothing is wrong. This exists because the failure used to be
  /// swallowed whole: the catch cleared `typing` and returned, so the thinking
  /// indicator simply stopped and no reply ever arrived. Ada looked like she had
  /// ignored the message. A turn can fail for reasons the user can act on —
  /// they are offline, the daily limit is spent, the providers are busy — and
  /// each deserves a different response from them.
  final String? error;

  bool get isEmpty => messages.isEmpty;

  /// Every change still waiting on the user, across the whole conversation.
  List<AdaAction> get outstandingActions => [
        for (final list in actionsByMessage.values)
          for (final a in list)
            if (a.status.isPending) a,
      ];

  AdaChatState copyWith({
    List<AdaMessage>? messages,
    bool? typing,
    bool? uploading,
    List<AdaAttachmentRef>? pendingAttachments,
    Map<String, List<AdaAction>>? actionsByMessage,
    Set<String>? decidingActionIds,
    String? error,
    bool clearError = false,
  }) =>
      AdaChatState(
        messages: messages ?? this.messages,
        typing: typing ?? this.typing,
        uploading: uploading ?? this.uploading,
        pendingAttachments: pendingAttachments ?? this.pendingAttachments,
        actionsByMessage: actionsByMessage ?? this.actionsByMessage,
        decidingActionIds: decidingActionIds ?? this.decidingActionIds,
        // `error ?? this.error` could never clear it, so clearing is explicit.
        error: clearError ? null : (error ?? this.error),
      );
}

/// A failed Ada turn, in words the person waiting can act on.
///
/// The distinctions are the point. "Something went wrong" is true of all of
/// these and useful for none — being offline, having spent the day's allowance,
/// and the model pool being busy each call for a different response, and only
/// one of them is worth retrying immediately.
String adaErrorMessage(Object error) {
  if (error is NetworkFailure) {
    return "Can't reach Ada — check your connection and try again.";
  }
  if (error is AuthFailure) {
    return 'Your session expired. Sign in again to keep chatting.';
  }
  if (error is ServerFailure) {
    // 429 is the daily cap or the rate limiter. Telling someone to retry now
    // would be a lie: the answer is to come back later.
    if (error.statusCode == 429) {
      return error.message.isNotEmpty
          ? error.message
          : "Ada has hit today's limit. She'll be back tomorrow.";
    }
    if (error.statusCode == 503) {
      return 'Ada is busy right now. Give it a moment and try again.';
    }
    // The server's own message beats a generic one — it is the layer that knows
    // what was actually wrong.
    if (error.message.isNotEmpty) return error.message;
  }
  return "Ada couldn't finish that. Tap retry to try again.";
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
      clearError: true,
    );
    try {
      final reply = await ref.read(adaRepositoryProvider).reply(
            payload,
            state.messages,
            attachments: attachments,
          );
      _appendTurn(reply, typing: false);
    } on Object catch (e) {
      // Say what happened. This used to be `catch (_)` with no message at all:
      // the thinking indicator stopped and no reply arrived, which is
      // indistinguishable from Ada ignoring the message — and left the user
      // with nothing to act on when the cause was something they could fix.
      state = state.copyWith(
        typing: false,
        // Restore staged files so a retry costs no re-upload.
        pendingAttachments: attachments,
        error: adaErrorMessage(e),
      );
    }
  }

  /// Dismiss the error banner without resending.
  void clearError() => state = state.copyWith(clearError: true);

  /// Resend the last user message after a failure.
  ///
  /// Drops the failed user bubble first so a retry does not stack a second copy
  /// of the same question in the transcript.
  Future<void> retryLast() async {
    final last = state.messages.lastWhere(
      (m) => m.role == AdaRole.user,
      orElse: () => const AdaMessage(id: '', role: AdaRole.user, text: ''),
    );
    if (last.text.isEmpty) return;
    // send() picks the staged files back up from state — the failure handler
    // already restored them, so they ride along without a re-upload.
    state = state.copyWith(
      messages: [
        for (final m in state.messages)
          if (m.id != last.id) m,
      ],
      clearError: true,
    );
    await send(last.text);
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
      final turns = await ref.read(adaRepositoryProvider).openConversation(id);
      state = AdaChatState(
        messages: turns.map((t) => t.message).toList(growable: false),
        actionsByMessage: {
          for (final t in turns)
            if (t.actions.isNotEmpty) t.message.id: t.actions,
        },
      );
    } on Object {
      state = const AdaChatState();
    }
  }

  /// Start a fresh conversation (clears the view + drops the active id).
  void newConversation() {
    ref.read(adaRepositoryProvider).startNewConversation();
    state = const AdaChatState();
  }

  /// Apply Ada's proposed schedule (from [messageId]) — legacy plan path.
  Future<void> applyPlan(String messageId) =>
      ref.read(adaRepositoryProvider).applyPlan(messageId);

  /// Approve one proposed change. Returns true when it was actually applied —
  /// the server can legitimately fail it if the underlying data moved on.
  Future<bool> approveAction(String actionId) =>
      _decide(actionId, approve: true);

  /// Decline one proposed change.
  Future<bool> rejectAction(String actionId) =>
      _decide(actionId, approve: false);

  Future<bool> _decide(String actionId, {required bool approve}) async {
    if (state.decidingActionIds.contains(actionId)) return false;
    state = state.copyWith(
      decidingActionIds: {...state.decidingActionIds, actionId},
    );
    try {
      final repo = ref.read(adaRepositoryProvider);
      final result = approve
          ? await repo.approveAction(actionId)
          : await repo.rejectAction(actionId);

      _replaceAction(result.action);
      if (result.followUp != null) {
        _appendTurn(
          (message: result.followUp!.message.toModel(), actions: result.followUp!.actions),
        );
      }
      return result.action.status.isApplied;
    } on Object {
      return false;
    } finally {
      state = state.copyWith(
        decidingActionIds: {...state.decidingActionIds}..remove(actionId),
      );
    }
  }

  /// Approve or decline everything outstanding in one go.
  Future<int> decideAll({required bool approve}) async {
    final outstanding = state.outstandingActions;
    if (outstanding.isEmpty) return 0;
    final ids = outstanding.map((a) => a.id).toSet();
    state = state.copyWith(
      decidingActionIds: {...state.decidingActionIds, ...ids},
    );
    try {
      final result =
          await ref.read(adaRepositoryProvider).decideAll(approve: approve);
      result.actions.forEach(_replaceAction);
      for (final turn in result.followUps) {
        _appendTurn((message: turn.message.toModel(), actions: turn.actions));
      }
      return result.actions.where((a) => a.status.isApplied).length;
    } on Object {
      return 0;
    } finally {
      state = state.copyWith(
        decidingActionIds: {...state.decidingActionIds}..removeAll(ids),
      );
    }
  }

  /// Append an assistant turn and index any cards it brought with it.
  void _appendTurn(AdaReplyResult turn, {bool? typing}) {
    state = state.copyWith(
      messages: [...state.messages, turn.message],
      typing: typing ?? state.typing,
      actionsByMessage: turn.actions.isEmpty
          ? state.actionsByMessage
          : {...state.actionsByMessage, turn.message.id: turn.actions},
    );
  }

  /// Swap an action for its post-decision version, wherever it lives.
  void _replaceAction(AdaAction updated) {
    final next = <String, List<AdaAction>>{};
    for (final entry in state.actionsByMessage.entries) {
      next[entry.key] = [
        for (final a in entry.value) a.id == updated.id ? updated : a,
      ];
    }
    state = state.copyWith(actionsByMessage: next);
  }
}

/// Past Ada conversations for the history panel.
final adaConversationsProvider = FutureProvider<List<AdaConversationDto>>(
  (ref) => ref.watch(adaRepositoryProvider).conversations(),
);
