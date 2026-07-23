import 'package:dio/dio.dart';

import '../dtos/ada_message_dto.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// A past Ada conversation, for the chat-history panel.
typedef AdaConversationDto = ({String id, String title, DateTime updatedAt});

/// A file the user uploaded to attach to an Ada message.
typedef AdaAttachmentRef = ({String key, String name, String? mimeType});

abstract interface class AdaSource {
  Future<AdaMessageDto> reply(
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

  /// The messages of a conversation, oldest-first.
  Future<List<AdaMessageDto>> messages(String conversationId);

  /// Apply the schedule Ada proposed in [messageId] to the user's plan.
  Future<void> applyPlan(String messageId);

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

  int _i = 0;

  @override
  String? conversationId;

  @override
  Future<AdaMessageDto> reply(
    String userText,
    List<AdaMessageDto> history, {
    List<AdaAttachmentRef> attachments = const [],
  }) {
    conversationId ??= 'mock-convo';
    final text = _canned[_i++ % _canned.length];
    return mockDelay(
      AdaMessageDto(
        id: 'ada-${DateTime.now().microsecondsSinceEpoch}',
        role: 'ada',
        text: text,
        createdAt: DateTime.now(),
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
  Future<List<AdaConversationDto>> conversations() => mockDelay([
        (id: 'mock-1', title: 'Exam-week schedule', updatedAt: DateTime.now()),
        (
          id: 'mock-2',
          title: 'NLP assignment breakdown',
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ]);

  @override
  Future<List<AdaMessageDto>> messages(String conversationId) => mockDelay([
        AdaMessageDto(
          id: 'm1',
          role: 'user',
          text: 'Can you help me plan exam week?',
          createdAt: DateTime.now(),
        ),
        AdaMessageDto(
          id: 'm2',
          role: 'ada',
          text: _canned.first,
          createdAt: DateTime.now(),
        ),
      ]);
}

/// Live impl — `/v1/ada` (contract §12.P). Transport is plain JSON (non-
/// streaming): the POST blocks until Ada's full turn is ready and returns both
/// the persisted user + assistant messages. A conversation is created lazily
/// and reused for the session.
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
  Future<List<AdaMessageDto>> messages(String conversationId) async {
    final body = await _dio.getMap('/ada/conversations/$conversationId/messages');
    return listOf(body, 'messages').map(_toDto).toList(growable: false);
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

  @override
  Future<AdaMessageDto> reply(
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
    );
    final messages = listOf(body, 'messages');
    final assistant = messages.lastWhere(
      (m) => m['is_user'] == false,
      orElse: () => messages.isNotEmpty ? messages.last : <String, dynamic>{},
    );
    return _toDto(assistant);
  }

  @override
  Future<void> applyPlan(String messageId) async {
    final cid = _conversationId;
    if (cid == null) return;
    await _dio.postMap('/ada/conversations/$cid/messages/$messageId/apply-plan');
  }

  AdaMessageDto _toDto(Map<String, dynamic> j) => AdaMessageDto(
        id: j['id'] as String? ?? 'ada-${DateTime.now().microsecondsSinceEpoch}',
        role: (j['is_user'] as bool? ?? false) ? 'user' : 'ada',
        text: j['text'] as String? ?? '',
        createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
        hasPlan: j['plan'] is List && (j['plan'] as List).isNotEmpty,
      );
}
