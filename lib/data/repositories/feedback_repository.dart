import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../adapters/adapters.dart';
import '../models/feedback_post.dart';
import '../sources/feedback_source.dart';

/// Feedback board — suggestions, votes and comments. Widgets never touch the
/// source or DTOs (README §7 seams); the repository converts both ways via
/// `data/adapters`.
class FeedbackRepository {
  FeedbackRepository(this._source);

  final FeedbackSource _source;

  Future<List<FeedbackPost>> posts() async {
    final dtos = await _source.posts();
    return dtos.map((d) => d.toModel()).toList(growable: false);
  }

  Future<FeedbackPost> create(FeedbackPost draft) async {
    final dto = await _source.create(draft.toDto());
    return dto.toModel();
  }

  Future<FeedbackPost> setVote(String id, {required bool voted}) async {
    final dto = await _source.setVote(id, voted: voted);
    return dto.toModel();
  }

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
