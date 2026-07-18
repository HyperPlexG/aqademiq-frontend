import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../adapters/adapters.dart';
import '../models/feedback_meta.dart';
import '../models/feedback_post.dart';
import '../sources/feedback_source.dart';

/// One page of board posts (models) plus the cursor for the next page.
typedef FeedbackPostsPage = ({List<FeedbackPost> posts, String? nextCursor});

/// Feedback board — suggestions, votes and comments. Widgets never touch the
/// source or DTOs (README §7 seams); the repository converts both ways via
/// `data/adapters`.
class FeedbackRepository {
  FeedbackRepository(this._source);

  final FeedbackSource _source;

  Future<FeedbackMeta> meta() async => (await _source.meta()).toModel();

  Future<FeedbackPostsPage> posts({
    String sort = 'top',
    String? status,
    String? category,
    String? query,
    String? cursor,
  }) async {
    final page = await _source.posts(
      sort: sort,
      status: status,
      category: category,
      query: query,
      cursor: cursor,
    );
    return (
      posts: page.posts.map((d) => d.toModel()).toList(growable: false),
      nextCursor: page.nextCursor,
    );
  }

  Future<FeedbackPost> create(FeedbackPost draft) async {
    final dto = await _source.create(draft.toDto());
    return dto.toModel();
  }

  /// Returns the server's authoritative `(votes, voted)` after the toggle.
  Future<FeedbackVoteResult> setVote(String id, {required bool voted}) =>
      _source.setVote(id, voted: voted);

  Future<List<FeedbackComment>> comments(String postId) async {
    final dtos = await _source.comments(postId);
    return dtos.map((d) => d.toModel()).toList(growable: false);
  }

  Future<FeedbackComment> addComment(FeedbackComment draft) async {
    final dto = await _source.addComment(draft.toDto());
    return dto.toModel();
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final source = Env.useMocks
      ? MockFeedbackSource()
      : ApiFeedbackSource(ref.watch(dioProvider));
  return FeedbackRepository(source);
});
