import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../dtos/feedback_dto.dart';
import '../fixtures/fixtures.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// One page of the board list: the posts plus the opaque cursor for the next
/// page (`null` when there are no more — FEEDBACK_BOARD_INTEGRATION.md §3).
typedef FeedbackFeedPage = ({List<FeedbackPostDto> posts, String? nextCursor});

/// The server's truth after a vote toggle (§3: "Treat you_voted + upvotes from
/// the response as truth").
typedef FeedbackVoteResult = ({int votes, bool voted});

/// Data source for the feedback board (suggestions, votes, comments).
///
/// Posts are addressed by their public **`ref`** (INTEGRATION.md §"IDs"); the
/// callers pass `post.id`, which for the live backend equals the ref as a
/// string. Every write requires a real (non-guest) account and returns `403`
/// for guests — the UI gates these before calling.
abstract interface class FeedbackSource {
  /// `GET /feedback/meta` — statuses + categories for the filter pills.
  Future<FeedbackMetaDto> meta();

  /// `GET /feedback/posts` with server-side sort / filter / search / paging.
  Future<FeedbackFeedPage> posts({
    String sort = 'top',
    String? status,
    String? category,
    String? query,
    String? cursor,
  });

  /// `POST /feedback/posts` — create a suggestion (429 past the daily limit).
  Future<FeedbackPostDto> create(FeedbackPostDto input);

  /// `POST` / `DELETE /feedback/posts/{ref}/vote` — one-per-user, idempotent.
  Future<FeedbackVoteResult> setVote(String id, {required bool voted});

  /// Comments for a post, read from `GET /feedback/posts/{ref}`.
  Future<List<FeedbackCommentDto>> comments(String postId);

  /// `POST /feedback/posts/{ref}/comments` — 409 if the thread is locked.
  Future<FeedbackCommentDto> addComment(FeedbackCommentDto input);
}

/// In-memory mock seeded from [Fixtures]; every call goes through [mockDelay]
/// so loading states are real (README §7 seam 3). Filtering / sorting / search
/// are applied here so the board behaves identically against mocks or the live
/// backend (which does the same server-side).
class MockFeedbackSource implements FeedbackSource {
  final List<FeedbackPostDto> _posts = [...Fixtures.feedbackPosts()];
  final List<FeedbackCommentDto> _comments = [...Fixtures.feedbackComments()];

  static const _statusLabels = <String, String>{
    'open': 'Open',
    'planned': 'Planned',
    'in_progress': 'In progress',
    'completed': 'Completed',
    'acknowledged': 'Acknowledged',
    'exists_already': 'Exists already',
  };
  static const _categoryLabels = <String, String>{
    'feature': 'Feature',
    'improvement': 'Improvement',
    'bug': 'Bug',
  };

  @override
  Future<FeedbackMetaDto> meta() => mockDelay(
        FeedbackMetaDto(
          statuses: [
            for (final e in _statusLabels.entries)
              FeedbackStatusMetaDto(
                key: e.key,
                label: e.value,
                onRoadmap: e.key == 'planned' || e.key == 'in_progress',
              ),
          ],
          categories: [
            for (final e in _categoryLabels.entries)
              FeedbackCategoryMetaDto(key: e.key, label: e.value),
          ],
        ),
      );

  @override
  Future<FeedbackFeedPage> posts({
    String sort = 'top',
    String? status,
    String? category,
    String? query,
    String? cursor,
  }) {
    final q = query?.trim().toLowerCase() ?? '';
    final filtered = [
      for (final p in _posts)
        if ((status == null || p.status == status) &&
            (category == null || p.category == category) &&
            (q.isEmpty ||
                p.title.toLowerCase().contains(q) ||
                p.body.toLowerCase().contains(q)))
          p,
    ]..sort(
        (a, b) => sort == 'new'
            ? b.createdAt.compareTo(a.createdAt)
            : (a.votes == b.votes
                ? b.createdAt.compareTo(a.createdAt)
                : b.votes.compareTo(a.votes)),
      );
    return mockDelay((posts: filtered, nextCursor: null));
  }

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
  Future<FeedbackVoteResult> setVote(String id, {required bool voted}) async {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) throw const NotFoundFailure(message: 'Suggestion not found.');
    final post = _posts[i];
    if (post.hasVoted != voted) {
      _posts[i] = post.copyWith(
        votes: post.votes + (voted ? 1 : -1),
        hasVoted: voted,
      );
    }
    return mockDelay((votes: _posts[i].votes, voted: _posts[i].hasVoted));
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

/// Live impl — `/feedback/*` under the app's `/v1` base URL
/// (FEEDBACK_BOARD_INTEGRATION.md §3). Reads/writes snake_case; addresses posts
/// by `ref`.
class ApiFeedbackSource implements FeedbackSource {
  ApiFeedbackSource(this._dio);
  final Dio _dio;

  @override
  Future<FeedbackMetaDto> meta() async {
    final body = await _dio.getMap('/feedback/meta');
    return FeedbackMetaDto(
      statuses: listOf(body, 'statuses')
          .map(
            (j) => FeedbackStatusMetaDto(
              key: j['key'] as String? ?? '',
              label: j['label'] as String? ?? '',
              color: j['color'] as String?,
              onRoadmap: j['on_roadmap'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
      categories: listOf(body, 'categories')
          .map(
            (j) => FeedbackCategoryMetaDto(
              key: j['key'] as String? ?? '',
              label: j['label'] as String? ?? '',
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<FeedbackFeedPage> posts({
    String sort = 'top',
    String? status,
    String? category,
    String? query,
    String? cursor,
  }) async {
    final body = await _dio.getMap('/feedback/posts', query: <String, dynamic>{
      'sort': sort,
      'status': ?status,
      'category': ?category,
      if (query != null && query.isNotEmpty) 'q': query,
      'cursor': ?cursor,
    });
    return (
      posts: listOf(body, 'posts').map(_postToDto).toList(growable: false),
      nextCursor: body['next_cursor'] as String?,
    );
  }

  @override
  Future<FeedbackPostDto> create(FeedbackPostDto input) async {
    final json = await _dio.postMap('/feedback/posts', <String, dynamic>{
      'title': input.title,
      if (input.body.isNotEmpty) 'body': input.body,
      'category': input.category,
    });
    return _postToDto(json);
  }

  @override
  Future<FeedbackVoteResult> setVote(String id, {required bool voted}) async {
    final json = voted
        ? await _dio.postMap('/feedback/posts/$id/vote')
        : await _dio.deleteMap('/feedback/posts/$id/vote');
    return (
      votes: (json['upvotes'] as num?)?.toInt() ?? 0,
      voted: json['you_voted'] as bool? ?? voted,
    );
  }

  @override
  Future<List<FeedbackCommentDto>> comments(String postId) async {
    // The contract exposes comments only via the post-detail endpoint.
    final body = await _dio.getMap('/feedback/posts/$postId');
    return listOf(body, 'comments')
        .map((j) => _commentToDto(j, postId))
        .toList(growable: false);
  }

  @override
  Future<FeedbackCommentDto> addComment(FeedbackCommentDto input) async {
    final json = await _dio.postMap(
      '/feedback/posts/${input.postId}/comments',
      <String, dynamic>{'body': input.body},
    );
    return _commentToDto(json, input.postId);
  }

  FeedbackPostDto _postToDto(Map<String, dynamic> j) {
    final ref = (j['ref'] as num?)?.toInt() ?? 0;
    return FeedbackPostDto(
      id: ref.toString(),
      number: ref,
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      status: j['status'] as String? ?? 'open',
      category: j['category'] as String? ?? 'feature',
      votes: (j['upvotes'] as num?)?.toInt() ?? 0,
      hasVoted: j['you_voted'] as bool? ?? false,
      commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
      author: _authorName(j['author']),
      createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
    );
  }

  FeedbackCommentDto _commentToDto(Map<String, dynamic> j, String postId) =>
      FeedbackCommentDto(
        id: (j['id'] ?? '').toString(),
        postId: postId,
        author: _authorName(j['author']),
        body: j['body'] as String? ?? '',
        isTeam: j['is_team'] as bool? ?? false,
        createdAt: parseDateTime(j['created_at']) ?? DateTime.now(),
      );

  /// `author` is an object `{ id, name, avatar_url }` and may be null (deleted
  /// account). We surface just the display name.
  String _authorName(Object? author) {
    if (author is Map) return author['name'] as String? ?? '';
    return '';
  }
}
