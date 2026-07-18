import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/auth/auth_repository.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/feedback_post.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../settings/providers/profile_controller.dart';

/// List / Board (kanban) view toggle for the feedback screen.
enum FeedbackView { list, board }

/// Sort orders offered by the sort sheet.
enum FeedbackSort { top, newest }

final feedbackViewProvider =
    NotifierProvider<FeedbackViewController, FeedbackView>(
  FeedbackViewController.new,
);

class FeedbackViewController extends Notifier<FeedbackView> {
  @override
  FeedbackView build() => FeedbackView.list;

  void set(FeedbackView view) => state = view;
}

final feedbackSortProvider =
    NotifierProvider<FeedbackSortController, FeedbackSort>(
  FeedbackSortController.new,
);

class FeedbackSortController extends Notifier<FeedbackSort> {
  @override
  FeedbackSort build() => FeedbackSort.top;

  void set(FeedbackSort sort) => state = sort;
}

/// Status chip filter for the list view (null = All).
final feedbackStatusFilterProvider =
    NotifierProvider<FeedbackStatusFilterController, FeedbackStatus?>(
  FeedbackStatusFilterController.new,
);

class FeedbackStatusFilterController extends Notifier<FeedbackStatus?> {
  @override
  FeedbackStatus? build() => null;

  void set(FeedbackStatus? status) => state = status;
}

/// Live search query, matched case-insensitively against title + body.
final feedbackSearchProvider =
    NotifierProvider<FeedbackSearchController, String>(
  FeedbackSearchController.new,
);

class FeedbackSearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// The post whose detail screen (and comments) is currently open. Set before
/// pushing the detail route — the comments controller watches this instead of
/// using a `.family` (matching the app's parameterize-by-provider idiom).
final selectedFeedbackPostIdProvider =
    NotifierProvider<SelectedFeedbackPostController, String?>(
  SelectedFeedbackPostController.new,
);

class SelectedFeedbackPostController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// All feedback posts + mutations (optimistic vote toggle, submit).
final feedbackPostsProvider =
    AsyncNotifierProvider<FeedbackPostsController, List<FeedbackPost>>(
  FeedbackPostsController.new,
);

class FeedbackPostsController extends AsyncNotifier<List<FeedbackPost>> {
  @override
  Future<List<FeedbackPost>> build() =>
      ref.watch(feedbackRepositoryProvider).posts();

  /// Optimistically toggle the user's vote, rolling back on failure
  /// (README §7: "optimistic updates for toggles").
  Future<void> toggleVote(FeedbackPost post) async {
    final previous = state.value ?? const <FeedbackPost>[];
    final voted = !post.hasVoted;
    final next = post.copyWith(
      hasVoted: voted,
      votes: post.votes + (voted ? 1 : -1),
    );
    state = AsyncData([
      for (final p in previous)
        if (p.id == post.id) next else p,
    ]);
    try {
      await ref.read(feedbackRepositoryProvider).setVote(post.id, voted: voted);
    } on Object catch (_) {
      // The notifier may have been recreated while the request was in flight
      // (Riverpod 3 recreates on invalidate) — touching state then throws.
      if (!ref.mounted) return;
      // Roll back only this post (within the *current* list) so concurrent
      // optimistic votes / refreshed comment counts are not clobbered.
      state = AsyncData([
        for (final p in state.value ?? previous)
          if (p.id == post.id) post else p,
      ]);
    }
  }

  /// Share a new suggestion. Returns the created post, or null on failure so
  /// the caller can surface a snackbar without try/catch in the widget.
  Future<FeedbackPost?> submit({
    required String title,
    required String body,
    required FeedbackCategory category,
  }) async {
    final guest = ref.read(isGuestProvider);
    final author = guest ? 'Guest' : ref.read(profileControllerProvider).name;
    final draft = FeedbackPost(
      id: '',
      number: 0,
      title: title,
      body: body,
      category: category,
      author: author,
      createdAt: DateTime.now(),
    );
    try {
      final created = await ref.read(feedbackRepositoryProvider).create(draft);
      if (ref.mounted) ref.invalidateSelf();
      return created;
    } on Object catch (_) {
      return null;
    }
  }
}

/// Comments for the post selected in [selectedFeedbackPostIdProvider].
final feedbackCommentsProvider =
    AsyncNotifierProvider<FeedbackCommentsController, List<FeedbackComment>>(
  FeedbackCommentsController.new,
);

class FeedbackCommentsController extends AsyncNotifier<List<FeedbackComment>> {
  @override
  Future<List<FeedbackComment>> build() {
    final id = ref.watch(selectedFeedbackPostIdProvider);
    if (id == null) return Future.value(const <FeedbackComment>[]);
    return ref.watch(feedbackRepositoryProvider).comments(id);
  }

  /// Add a comment to the open post. Returns false on failure so the composer
  /// can keep the draft text.
  Future<bool> add(String body) async {
    final postId = ref.read(selectedFeedbackPostIdProvider);
    if (postId == null) return false;
    final guest = ref.read(isGuestProvider);
    final author = guest ? 'Guest' : ref.read(profileControllerProvider).name;
    final draft = FeedbackComment(
      id: '',
      postId: postId,
      author: author,
      body: body,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(feedbackRepositoryProvider).addComment(draft);
    } on Object catch (_) {
      return false;
    }
    // Refresh bookkeeping outside the try: the comment IS persisted at this
    // point, so a recreated notifier must not be misreported as a failure.
    if (ref.mounted) {
      ref.invalidateSelf();
      // Comment counts on the board changed too.
      ref.invalidate(feedbackPostsProvider);
    }
    return true;
  }
}
