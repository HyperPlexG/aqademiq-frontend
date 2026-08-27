import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/feedback_meta.dart';
import '../../../data/models/feedback_post.dart';
import '../../../data/repositories/feedback_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../settings/providers/profile_controller.dart';

/// List / Board (kanban) view toggle for the feedback screen.
enum FeedbackView { list, board }

/// Sort orders offered by the sort sheet.
enum FeedbackSort { top, newest }

/// Result of posting a comment — the composer branches on this.
enum AddCommentOutcome { ok, locked, failed }

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

/// Applied (debounced) search query. The text field debounces keystrokes before
/// writing here so each change is one server round-trip, not one per character.
final feedbackSearchProvider =
    NotifierProvider<FeedbackSearchController, String>(
  FeedbackSearchController.new,
);

class FeedbackSearchController extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Board configuration (`GET /feedback/meta`) — drives the status filter pills.
/// Loaded once; failures fall back to the built-in status enum in the UI.
final feedbackMetaProvider = FutureProvider<FeedbackMeta>(
  (ref) => ref.watch(feedbackRepositoryProvider).meta(),
);

/// The post whose detail screen (and comments) is currently open. Holds the
/// post's `ref` (as a string, matching `post.id`). Set before pushing the detail
/// route — the comments controller watches this instead of using a `.family`.
final selectedFeedbackPostIdProvider =
    NotifierProvider<SelectedFeedbackPostController, String?>(
  SelectedFeedbackPostController.new,
);

class SelectedFeedbackPostController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// All feedback posts + mutations. Filtering, sorting and search are applied
/// server-side: the controller's `build` re-runs whenever the sort / status /
/// search / view providers change, fetching a fresh first page; `loadMore`
/// appends the next cursor page.
final feedbackPostsProvider =
    AsyncNotifierProvider<FeedbackPostsController, List<FeedbackPost>>(
  FeedbackPostsController.new,
);

class FeedbackPostsController extends AsyncNotifier<List<FeedbackPost>> {
  String? _nextCursor;
  bool _loadingMore = false;

  /// Whether another page is available (drives the list's load-more trigger).
  bool get hasMore => _nextCursor != null;

  @override
  Future<List<FeedbackPost>> build() async {
    final sort = ref.watch(feedbackSortProvider);
    final view = ref.watch(feedbackViewProvider);
    // The kanban board groups by status itself, so it wants every status.
    final status = view == FeedbackView.board
        ? null
        : ref.watch(feedbackStatusFilterProvider);
    final query = ref.watch(feedbackSearchProvider).trim();

    final page = await ref.watch(feedbackRepositoryProvider).posts(
          sort: sort == FeedbackSort.newest ? 'new' : 'top',
          status: status?.wire,
          query: query.isEmpty ? null : query,
        );
    _nextCursor = page.nextCursor;
    return page.posts;
  }

  /// Fetch and append the next page (no-op when there are no more / in flight).
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final sort = ref.read(feedbackSortProvider);
      final view = ref.read(feedbackViewProvider);
      final status = view == FeedbackView.board
          ? null
          : ref.read(feedbackStatusFilterProvider);
      final query = ref.read(feedbackSearchProvider).trim();

      final page = await ref.read(feedbackRepositoryProvider).posts(
            sort: sort == FeedbackSort.newest ? 'new' : 'top',
            status: status?.wire,
            query: query.isEmpty ? null : query,
            cursor: cursor,
          );
      if (!ref.mounted) return;
      _nextCursor = page.nextCursor;
      state = AsyncData([...?state.value, ...page.posts]);
    } on Object {
      // Keep what we have; the user can scroll again to retry.
    } finally {
      _loadingMore = false;
    }
  }

  /// Optimistically toggle the user's vote, then reconcile with the server's
  /// authoritative `upvotes`/`you_voted`, rolling back on failure
  /// (README §7: "optimistic updates for toggles"; INTEGRATION.md §3: vote
  /// counts come from the server). Guests are gated in the UI before calling.
  Future<void> toggleVote(FeedbackPost post) async {
    final previous = state.value ?? const <FeedbackPost>[];
    final voted = !post.hasVoted;
    final optimistic = post.copyWith(
      hasVoted: voted,
      votes: post.votes + (voted ? 1 : -1),
    );
    state = AsyncData([
      for (final p in previous)
        if (p.id == post.id) optimistic else p,
    ]);
    try {
      final result = await ref
          .read(feedbackRepositoryProvider)
          .setVote(post.id, voted: voted);
      // The notifier may have been recreated while the request was in flight
      // (Riverpod 3 recreates on invalidate) — touching state then throws, and
      // so does reading a provider off a disposed ref, which is why the haptic
      // sits below this guard rather than above it.
      if (!ref.mounted) return;
      // Lightest thing in Tier 2 — it is a small commitment. On the server's
      // answer rather than the tap, so a vote that did not stick stays silent.
      ref.read(hapticsProvider).voteCast();
      state = AsyncData([
        for (final p in state.value ?? previous)
          if (p.id == post.id)
            p.copyWith(votes: result.votes, hasVoted: result.voted)
          else
            p,
      ]);
    } on Object catch (_) {
      if (!ref.mounted) return;
      // Roll back only this post (within the *current* list) so concurrent
      // optimistic votes / refreshed comment counts are not clobbered.
      state = AsyncData([
        for (final p in state.value ?? previous)
          if (p.id == post.id) post else p,
      ]);
    }
  }

  /// Share a new suggestion. Throws a [Failure] on error (429 daily limit, 403
  /// guest, 400 validation) so the caller can surface the right message; the UI
  /// gates guests before calling.
  Future<FeedbackPost> submit({
    required String title,
    required String body,
    required FeedbackCategory category,
  }) async {
    final draft = FeedbackPost(
      id: '',
      number: 0,
      title: title,
      body: body,
      category: category,
      author: ref.read(profileControllerProvider).name,
      createdAt: DateTime.now(),
    );
    final created = await ref.read(feedbackRepositoryProvider).create(draft);
    // After the post lands. The 403 / 429 / 400 paths throw out of here and are
    // handled by the caller with a prompt or a message — a failed post is not
    // one of Feedback's two budgeted events (§7).
    if (ref.mounted) {
      ref.read(hapticsProvider).suggestionPosted();
      ref.invalidateSelf();
    }
    return created;
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

  /// Add a comment to the open post. Returns [AddCommentOutcome.locked] on a 409
  /// (locked thread) so the composer can disable itself, and
  /// [AddCommentOutcome.failed] on other errors so it can keep the draft text.
  /// Guests are gated in the UI before calling.
  Future<AddCommentOutcome> add(String body) async {
    final postId = ref.read(selectedFeedbackPostIdProvider);
    if (postId == null) return AddCommentOutcome.failed;
    final draft = FeedbackComment(
      id: '',
      postId: postId,
      author: ref.read(profileControllerProvider).name,
      body: body,
      createdAt: DateTime.now(),
    );
    try {
      await ref.read(feedbackRepositoryProvider).addComment(draft);
    } on ServerFailure catch (e) {
      return e.statusCode == 409
          ? AddCommentOutcome.locked
          : AddCommentOutcome.failed;
    } on Object {
      return AddCommentOutcome.failed;
    }
    // Refresh bookkeeping outside the try: the comment IS persisted at this
    // point, so a recreated notifier must not be misreported as a failure.
    if (ref.mounted) {
      ref
        ..invalidateSelf()
        // Comment counts on the board changed too.
        ..invalidate(feedbackPostsProvider);
    }
    return AddCommentOutcome.ok;
  }
}
