import 'package:dio/dio.dart';

import '../dtos/ada_message_dto.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

abstract interface class AdaSource {
  Future<AdaMessageDto> reply(String userText, List<AdaMessageDto> history);
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
  Future<AdaMessageDto> reply(String userText, List<AdaMessageDto> history) {
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
}

/// Live impl — `/v1/ada` (contract §12.P). Transport is plain JSON (non-
/// streaming): the POST blocks until Ada's full turn is ready and returns both
/// the persisted user + assistant messages. A conversation is created lazily
/// and reused for the session.
class ApiAdaSource implements AdaSource {
  ApiAdaSource(this._dio);
  final Dio _dio;

  String? _conversationId;

  Future<String> _ensureConversation() async {
    final existing = _conversationId;
    if (existing != null) return existing;
    final body = await _dio.postMap('/ada/conversations', const <String, dynamic>{});
    final id = body['id'] as String? ?? '';
    _conversationId = id;
    return id;
  }

  @override
  Future<AdaMessageDto> reply(String userText, List<AdaMessageDto> history) async {
    final cid = await _ensureConversation();
    final body = await _dio.postMap(
      '/ada/conversations/$cid/messages',
      {'text': userText},
    );
    final messages = listOf(body, 'messages');
    final assistant = messages.lastWhere(
      (m) => m['is_user'] == false,
      orElse: () => messages.isNotEmpty ? messages.last : <String, dynamic>{},
    );
    return _toDto(assistant);
  }

  AdaMessageDto _toDto(Map<String, dynamic> j) => AdaMessageDto(
        id: j['id'] as String? ?? 'ada-${DateTime.now().microsecondsSinceEpoch}',
        role: (j['is_user'] as bool? ?? false) ? 'user' : 'ada',
        text: j['text'] as String? ?? '',
        createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
      );
}
