import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../dtos/feedback_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// Data source for the feedback board (suggestions, votes, comments).
abstract interface class FeedbackSource {
  Future<List<FeedbackPostDto>> posts();
  Future<FeedbackPostDto> create(FeedbackPostDto input);
  Future<FeedbackPostDto> setVote(String id, {required bool voted});
  Future<List<FeedbackCommentDto>> comments(String postId);
  Future<FeedbackCommentDto> addComment(FeedbackCommentDto input);
}

/// In-memory mock seeded from [Fixtures]; every call goes through [mockDelay]
/// so loading states are real (README §7 seam 3).
class MockFeedbackSource implements FeedbackSource {
  final List<FeedbackPostDto> _posts = [...Fixtures.feedbackPosts()];
  final List<FeedbackCommentDto> _comments = [...Fixtures.feedbackComments()];

  @override
  Future<List<FeedbackPostDto>> posts() =>
      mockDelay(List<FeedbackPostDto>.unmodifiable(_posts));

  @override
  Future<FeedbackPostDto> create(FeedbackPostDto input) async {
    var maxNumber = 0;
    for (final p in _posts) {
      if (p.number > maxNumber) maxNumber = p.number;
    }
    // New suggestions open with the author's own vote already counted
    // (Featurebase-style auto-upvote).
    final created = input.copyWith(
      id: input.id.isEmpty
          ? 'fb-${DateTime.now().microsecondsSinceEpoch}'
          : input.id,
      number: maxNumber + 1,
      status: 'open',
      votes: 1,
      hasVoted: true,
    );
    _posts.insert(0, created);
    return mockDelay(created);
  }

  @override
  Future<FeedbackPostDto> setVote(String id, {required bool voted}) async {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) throw const NotFoundFailure(message: 'Suggestion not found.');
    final post = _posts[i];
    if (post.hasVoted == voted) return mockDelay(post);
    final updated = post.copyWith(
      votes: post.votes + (voted ? 1 : -1),
      hasVoted: voted,
    );
    _posts[i] = updated;
    return mockDelay(updated);
  }

  @override
  Future<List<FeedbackCommentDto>> comments(String postId) => mockDelay(
        List<FeedbackCommentDto>.unmodifiable(
          _comments.where((c) => c.postId == postId),
        ),
      );

  @override
  Future<FeedbackCommentDto> addComment(FeedbackCommentDto input) async {
    final created = input.copyWith(
      id: input.id.isEmpty
          ? 'fbc-${DateTime.now().microsecondsSinceEpoch}'
          : input.id,
    );
    _comments.add(created);
    final i = _posts.indexWhere((p) => p.id == created.postId);
    if (i >= 0) {
      _posts[i] = _posts[i].copyWith(commentCount: _posts[i].commentCount + 1);
    }
    return mockDelay(created);
  }
}

/// Live impl — `/feedback` (screen→endpoint rows in INTEGRATION.md §2).
class ApiFeedbackSource implements FeedbackSource {
  ApiFeedbackSource(this._dio);
  final Dio _dio;

  @override
  Future<List<FeedbackPostDto>> posts() async {
    final body = await _dio.getMap('/feedback');
    return listOf(body, 'posts').map(_postToDto).toList(growable: false);
  }

  @override
  Future<FeedbackPostDto> create(FeedbackPostDto input) async {
    final json = await _dio.postMap('/feedback', <String, dynamic>{
      'title': input.title,
      if (input.body.isNotEmpty) 'body': input.body,
      'category': input.category,
    });
    return _postToDto(json);
  }

  @override
  Future<FeedbackPostDto> setVote(String id, {required bool voted}) async {
    final json = await _dio.putMap(
      '/feedback/$id/vote',
      <String, dynamic>{'voted': voted},
    );
    return _postToDto(json);
  }

  @override
  Future<List<FeedbackCommentDto>> comments(String postId) async {
    final body = await _dio.getMap('/feedback/$postId/comments');
    return listOf(body, 'comments').map(_commentToDto).toList(growable: false);
  }

  @override
  Future<FeedbackCommentDto> addComment(FeedbackCommentDto input) async {
    final json = await _dio.postMap(
      '/feedback/${input.postId}/comments',
      <String, dynamic>{'body': input.body},
    );
    return _commentToDto(json);
  }

  FeedbackPostDto _postToDto(Map<String, dynamic> j) => FeedbackPostDto(
        id: j['id'] as String? ?? '',
        number: (j['number'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        category: j['category'] as String? ?? 'feature',
        votes: (j['votes'] as num?)?.toInt() ?? 0,
        hasVoted: j['has_voted'] as bool? ?? false,
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        author: j['author'] as String? ?? '',
        createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
      );

  FeedbackCommentDto _commentToDto(Map<String, dynamic> j) =>
      FeedbackCommentDto(
        id: j['id'] as String? ?? '',
        postId: j['post_id'] as String? ?? '',
        author: j['author'] as String? ?? '',
        body: j['body'] as String? ?? '',
        isTeam: j['is_team'] as bool? ?? false,
        createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
      );
}
