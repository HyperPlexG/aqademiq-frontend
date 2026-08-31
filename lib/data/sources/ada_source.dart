import 'package:dio/dio.dart';

import '../dtos/ada_message_dto.dart';
import '../models/ada_action.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// A past Ada conversation, for the chat-history panel.
typedef AdaConversationDto = ({String id, String title, DateTime updatedAt});

/// A file the user uploaded to attach to an Ada message.
typedef AdaAttachmentRef = ({String key, String name, String? mimeType});

/// One assistant turn: what Ada said, plus any changes it is asking to make.
typedef AdaTurn = ({AdaMessageDto message, List<AdaAction> actions});

/// The result of approving or rejecting a single action. `followUp` is Ada's
/// next turn — the agent resumes once nothing in its run is still undecided, so
/// it can verify the change, adapt, or propose a correction.
typedef AdaDecisionResult = ({AdaAction action, AdaTurn? followUp, String? error});

typedef AdaBulkDecision = ({List<AdaAction> actions, List<AdaTurn> followUps});

abstract interface class AdaSource {
  Future<AdaTurn> reply(
    String userText,
    List<AdaMessageDto> history, {
    List<AdaAttachmentRef> attachments,
  });

  /// Presign + upload a file for the active conversation, returning the ref to
  /// attach to the next message. Creates a conversation if none is active.
  Future<AdaAttachmentRef> upload({
    required String name,
    String? mimeType,
    required List<int> bytes,
  });

  /// The signed-in user's past conversations, most-recent first.
  Future<List<AdaConversationDto>> conversations();

  /// The messages of a conversation, oldest-first, each with its action cards.
  Future<List<AdaTurn>> messages(String conversationId);

  /// Apply the schedule Ada proposed in [messageId] (legacy pre-agent plans).
  Future<void> applyPlan(String messageId);

  /// Approve one proposed change. The server executes it and re-validates
  /// ownership first — approval never widens what the action may touch.
  Future<AdaDecisionResult> approveAction(String actionId);

  /// Decline one proposed change; nothing is written.
  Future<AdaDecisionResult> rejectAction(String actionId);

  /// Approve or decline every outstanding change in the active conversation.
  Future<AdaBulkDecision> decideAll({required bool approve});

  /// Switch the active conversation. `null` starts a fresh one on the next reply.
  set conversationId(String? id);
  String? get conversationId;
}

class MockAdaSource implements AdaSource {
  static const _canned = [
    "Let's break that down. I can add a few focused steps to your plan — want me to schedule them this week?",
    'Got it. Based on your peak focus time, mornings look best for deep work. Shall I block 9–11?',
    "Nice progress! You're on a 5-day streak. Keep one small task for today so it stays alive.",
    'I can split that into 3 microtasks (~25 min each) and drop them into Anytime. Sound good?',
  ];

  /// Words that make the mock propose changes, so mock mode exercises the same
  /// confirmation UI as the live agent (README §7, seam 3: mock == real).
  static final _writeIntent = RegExp(
    r'\b(add|create|schedule|plan|move|delete|remove|rename|change|set|block|reschedule)\b',
    caseSensitive: false,
  );

  int _i = 0;
  int _actionSeq = 0;
  final _actions = <String, AdaAction>{};

  @override
  String? conversationId;

  String _nextId() => 'mock-action-${++_actionSeq}';

  List<AdaAction> _proposalsFor(String userText) {
    if (!_writeIntent.hasMatch(userText)) return const [];
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    return [
      AdaAction(
        id: _nextId(),
        operation: AdaActionOperation.create,
        resource: 'task',
        title: 'Add task “Review lecture notes”',
        fields: [
          AdaActionField(label: 'Date', to: ymd(tomorrow)),
          const AdaActionField(label: 'Duration', to: '45 min'),
          const AdaActionField(label: 'Subject', to: 'Computer Networks'),
        ],
      ),
      AdaAction(
        id: _nextId(),
        operation: AdaActionOperation.update,
        resource: 'task',
        title: 'Edit task “Problem set 4”',
        fields: [
          const AdaActionField(label: 'Duration', from: '30 min', to: '1h'),
        ],
      ),
    ];
  }

  @override
  Future<AdaTurn> reply(
    String userText,
    List<AdaMessageDto> history, {
    List<AdaAttachmentRef> attachments = const [],
  }) {
    conversationId ??= 'mock-convo';
    final proposals = _proposalsFor(userText);
    for (final a in proposals) {
      _actions[a.id] = a;
    }
    final text = proposals.isEmpty
        ? _canned[_i++ % _canned.length]
        : "Here's what I'd change — confirm below and I'll apply it.";
    return mockDelay(
      (
        message: AdaMessageDto(
          id: 'ada-${DateTime.now().microsecondsSinceEpoch}',
          role: 'ada',
          text: text,
          createdAt: DateTime.now(),
        ),
        actions: proposals,
      ),
      ms: 700,
    );
  }

  @override
  Future<AdaAttachmentRef> upload({
    required String name,
    String? mimeType,
    required List<int> bytes,
  }) {
    conversationId ??= 'mock-convo';
    return mockDelay((key: 'mock/$name', name: name, mimeType: mimeType), ms: 500);
  }

  @override
  Future<void> applyPlan(String messageId) => mockDelay(null);

  @override
  Future<AdaDecisionResult> approveAction(String actionId) {
    final current = _actions[actionId];
    final applied = (current ?? _placeholder(actionId))
        .copyWith(status: AdaActionStatus.executed);
    _actions[actionId] = applied;
    return mockDelay(
      (action: applied, followUp: _followUpIfSettled(), error: null),
      ms: 400,
    );
  }

  @override
  Future<AdaDecisionResult> rejectAction(String actionId) {
    final current = _actions[actionId];
    final declined = (current ?? _placeholder(actionId))
        .copyWith(status: AdaActionStatus.rejected);
    _actions[actionId] = declined;
    return mockDelay(
      (action: declined, followUp: _followUpIfSettled(), error: null),
      ms: 300,
    );
  }

  @override
  Future<AdaBulkDecision> decideAll({required bool approve}) {
    final decided = <AdaAction>[];
    for (final entry in _actions.entries.toList()) {
      if (!entry.value.status.isPending) continue;
      final next = entry.value.copyWith(
        status: approve ? AdaActionStatus.executed : AdaActionStatus.rejected,
      );
      _actions[entry.key] = next;
      decided.add(next);
    }
    final followUp = _followUpIfSettled();
    return mockDelay(
      (actions: decided, followUps: followUp == null ? <AdaTurn>[] : [followUp]),
      ms: 500,
    );
  }

  AdaAction _placeholder(String id) => AdaAction(
        id: id,
        operation: AdaActionOperation.update,
        resource: 'task',
        title: 'Change',
      );

  /// Mirrors the real agent resuming once every proposal has been decided.
  AdaTurn? _followUpIfSettled() {
    if (_actions.values.any((a) => a.status.isPending)) return null;
    final applied = _actions.values.where((a) => a.status.isApplied).length;
    final declined = _actions.values.where((a) => a.status.isDeclined).length;
    if (applied == 0 && declined == 0) return null;
    _actions.clear();
    final parts = [
      if (applied > 0) '$applied applied',
      if (declined > 0) '$declined declined',
    ];
    return (
      message: AdaMessageDto(
        id: 'ada-${DateTime.now().microsecondsSinceEpoch}',
        role: 'ada',
        text: 'Done — ${parts.join(', ')}. Your plan is up to date.',
        createdAt: DateTime.now(),
      ),
      actions: const <AdaAction>[],
    );
  }

  @override
  Future<List<AdaConversationDto>> conversations() => mockDelay([
        (id: 'mock-1', title: 'Exam-week schedule', updatedAt: DateTime.now()),
        (
          id: 'mock-2',
          title: 'NLP assignment breakdown',
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ]);

  @override
  Future<List<AdaTurn>> messages(String conversationId) => mockDelay([
        (
          message: AdaMessageDto(
            id: 'm1',
            role: 'user',
            text: 'Can you help me plan exam week?',
            createdAt: DateTime.now(),
          ),
          actions: const <AdaAction>[],
        ),
        (
          message: AdaMessageDto(
            id: 'm2',
            role: 'ada',
            text: _canned.first,
            createdAt: DateTime.now(),
          ),
          actions: const <AdaAction>[],
        ),
      ]);
}

/// Live impl — `/v1/ada` (contract §12.P). Transport is plain JSON (non-
/// streaming): the POST blocks until the agent's turn is ready and returns the
/// persisted user + assistant messages plus anything awaiting confirmation. A
/// conversation is created lazily and reused for the session.
class ApiAdaSource implements AdaSource {
  ApiAdaSource(this._dio);
  final Dio _dio;

  String? _conversationId;

  @override
  String? get conversationId => _conversationId;

  @override
  set conversationId(String? id) => _conversationId = id;

  Future<String> _ensureConversation() async {
    final existing = _conversationId;
    if (existing != null) return existing;
    final body = await _dio.postMap('/ada/conversations', const <String, dynamic>{});
    final id = body['id'] as String? ?? '';
    _conversationId = id;
    return id;
  }

  @override
  Future<List<AdaConversationDto>> conversations() async {
    final body = await _dio.getMap('/ada/conversations');
    return listOf(body, 'conversations').map((j) {
      return (
        id: j['id'] as String? ?? '',
        title: (j['title'] as String?)?.trim().isNotEmpty ?? false
            ? j['title'] as String
            : 'Conversation',
        updatedAt: parseDateTime(j['last_message_at']) ??
            parseDateTime(j['created_at']) ??
            DateTime.now(),
      );
    }).toList(growable: false);
  }

  @override
  Future<List<AdaTurn>> messages(String conversationId) async {
    final body = await _dio.getMap('/ada/conversations/$conversationId/messages');
    return listOf(body, 'messages').map(_toTurn).toList(growable: false);
  }

  @override
  Future<AdaAttachmentRef> upload({
    required String name,
    String? mimeType,
    required List<int> bytes,
  }) async {
    final cid = await _ensureConversation();
    final contentType = mimeType ?? 'application/octet-stream';
    // Presign against Ada's own upload endpoint, then PUT bytes straight to
    // storage (bare Dio so the signed URL isn't sent our API base/auth headers).
    final init = await _dio.postMap('/ada/uploads', {
      'conversation_id': cid,
      'name': name,
      'mime_type': contentType,
      'size_bytes': bytes.length,
    });
    final uploadUrl = init['upload_url'] as String;
    final key = init['key'] as String;
    await Dio().put<void>(
      uploadUrl,
      data: Stream<List<int>>.fromIterable([bytes]),
      options: Options(
        headers: <String, dynamic>{
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
    return (key: key, name: name, mimeType: mimeType);
  }

  /// How long to wait for the agent, as opposed to an ordinary request.
  ///
  /// The client-wide receiveTimeout is 30s, which is right for CRUD and wrong
  /// for this: an Ada turn is several provider calls, and reading an attachment
  /// pushes it well past a minute — one measured run took 65.6s to answer a PDF.
  /// At 30s the app stopped listening while the server was still working, so the
  /// reply landed in the database and never on screen. It looked like the
  /// attachment had silently failed when it had actually succeeded.
  ///
  /// Deliberately scoped to the agent endpoints rather than raised globally: a
  /// 2-minute client-wide timeout would mean any hung request freezes the UI for
  /// two minutes, which is a bad trade for the ~40 endpoints that answer in
  /// under a second. Must stay above the server's ADA_RUN_DEADLINE_MS, or the
  /// client gives up on work the server is about to finish.
  static const _agentTimeout = Duration(minutes: 2);
  static final _agentOptions = Options(receiveTimeout: _agentTimeout);

  @override
  Future<AdaTurn> reply(
    String userText,
    List<AdaMessageDto> history, {
    List<AdaAttachmentRef> attachments = const [],
  }) async {
    final cid = await _ensureConversation();
    final body = await _dio.postMap(
      '/ada/conversations/$cid/messages',
      <String, dynamic>{
        'text': userText,
        if (attachments.isNotEmpty)
          'attachments': <Map<String, dynamic>>[
            for (final a in attachments)
              <String, dynamic>{
                'key': a.key,
                'name': a.name,
                if (a.mimeType != null) 'mime_type': a.mimeType,
              },
          ],
      },
      _agentOptions,
    );
    final messages = listOf(body, 'messages');
    final assistant = messages.lastWhere(
      (m) => m['is_user'] == false,
      orElse: () => messages.isNotEmpty ? messages.last : <String, dynamic>{},
    );
    return _toTurn(assistant);
  }

  @override
  Future<void> applyPlan(String messageId) async {
    final cid = _conversationId;
    if (cid == null) return;
    await _dio.postMap('/ada/conversations/$cid/messages/$messageId/apply-plan');
  }

  @override
  Future<AdaDecisionResult> approveAction(String actionId) =>
      _decide('/ada/actions/$actionId/approve');

  @override
  Future<AdaDecisionResult> rejectAction(String actionId) =>
      _decide('/ada/actions/$actionId/reject');

  Future<AdaDecisionResult> _decide(String path) async {
    // Approving resumes the agent so it can verify and carry on — same cost as
    // a turn, so the same allowance.
    final body = await _dio.postMap(path, null, _agentOptions);
    final action = body['action'];
    final message = body['message'];
    return (
      action: AdaAction.fromJson(
        action is Map<String, dynamic> ? action : const <String, dynamic>{},
      ),
      followUp: message is Map<String, dynamic> ? _toTurn(message) : null,
      error: body['error'] as String?,
    );
  }

  @override
  Future<AdaBulkDecision> decideAll({required bool approve}) async {
    final cid = _conversationId;
    if (cid == null) return (actions: const <AdaAction>[], followUps: const <AdaTurn>[]);
    final body = await _dio.postMap(
      '/ada/conversations/$cid/actions/decide',
      <String, dynamic>{'approve': approve},
      _agentOptions,
    );
    return (
      actions: listOf(body, 'actions').map(AdaAction.fromJson).toList(growable: false),
      followUps: listOf(body, 'messages').map(_toTurn).toList(growable: false),
    );
  }

  AdaTurn _toTurn(Map<String, dynamic> j) => (
        message: AdaMessageDto(
          id: j['id'] as String? ?? 'ada-${DateTime.now().microsecondsSinceEpoch}',
          role: (j['is_user'] as bool? ?? false) ? 'user' : 'ada',
          text: j['text'] as String? ?? '',
          createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
          hasPlan: j['plan'] is List && (j['plan'] as List).isNotEmpty,
        ),
        actions: (j['actions'] is List)
            ? (j['actions'] as List)
                .whereType<Map<String, dynamic>>()
                .map(AdaAction.fromJson)
                .toList(growable: false)
            : const <AdaAction>[],
      );
}
