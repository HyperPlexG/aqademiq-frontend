import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/launch_external.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/feedback_post.dart';
import '../../../shared/icons/app_icon.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/circle_back_button.dart';
import '../../../shared/widgets/ic.dart';
import '../providers/feedback_providers.dart';
import 'sheets/create_account_prompt.dart';
import 'sheets/feedback_sort_sheet.dart';
import 'sheets/new_suggestion_sheet.dart';
import 'widgets/feedback_bits.dart';

/// The Tiimo-style feedback board: community suggestions with votes and
/// statuses, a List / Board (kanban) toggle, search, status filters and
/// sorting. Entry: Settings → About → "Feedback & suggestions".
///
/// v11 `feedback-list` / `feedback-list-filled` / `feedback-list-filters` /
/// `feedback-board`: a 22 title beside the back button, the List / Board
/// toggle, a 44 search pill and sort pill, and "Make a suggestion" floating
/// over the content.
class FeedbackBoardScreen extends ConsumerStatefulWidget {
  const FeedbackBoardScreen({super.key});

  @override
  ConsumerState<FeedbackBoardScreen> createState() =>
      _FeedbackBoardScreenState();
}

class _FeedbackBoardScreenState extends ConsumerState<FeedbackBoardScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(feedbackSearchProvider);
    _hasText = _search.text.isNotEmpty;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Debounce keystrokes into a single applied query so search is one server
  /// round-trip, not one per character.
  void _onSearchChanged(String value) {
    if (_hasText != value.isNotEmpty) setState(() => _hasText = value.isNotEmpty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(feedbackSearchProvider.notifier).set(value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _hasText = false);
    ref.read(feedbackSearchProvider.notifier).set('');
  }

  /// Guests may browse but not write — prompt sign-up at the point of action
  /// (FEEDBACK_BOARD_INTEGRATION.md §"Guest rule"). Returns true if the caller
  /// may proceed.
  bool _requireAccount(String reason) {
    if (!ref.read(isGuestProvider)) return true;
    unawaited(showCreateAccountPrompt(context, ref, reason: reason));
    return false;
  }

  void _open(FeedbackPost post) {
    ref.read(selectedFeedbackPostIdProvider.notifier).select(post.id);
    unawaited(context.push(Routes.feedbackPost(post.id)));
  }

  void _vote(FeedbackPost post) {
    if (!_requireAccount('vote on suggestions')) return;
    unawaited(ref.read(feedbackPostsProvider.notifier).toggleVote(post));
  }

  Future<void> _suggest() async {
    if (!_requireAccount('post a suggestion')) return;
    var draft = await showNewSuggestionSheet(context);
    while (true) {
      if (draft == null || !mounted) return;
      try {
        await ref.read(feedbackPostsProvider.notifier).submit(
              title: draft.title,
              body: draft.body,
              category: draft.category,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks! Your suggestion is on the board.'),
          ),
        );
        return;
      } on Failure catch (e) {
        if (!mounted) return;
        // 403 (guest) → prompt sign-up and stop; 429 (daily limit) → tell them
        // and stop. Otherwise keep the draft and let them retry.
        if (e is AuthFailure) {
          unawaited(showCreateAccountPrompt(context, ref, reason: 'post a suggestion'));
          return;
        }
        if (e is ServerFailure && e.statusCode == 429) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can post up to 2 suggestions per day.'),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        draft = await showNewSuggestionSheet(context, initial: draft);
      }
    }
  }

  Future<void> _pickSort() async {
    final result = await showFeedbackSortSheet(
      context,
      current: ref.read(feedbackSortProvider),
    );
    if (!mounted || result == null) return;
    ref.read(feedbackSortProvider.notifier).set(result);
  }

  /// Status filter pills, driven by `GET /feedback/meta` when loaded and
  /// falling back to the built-in status enum otherwise. The pill's filter
  /// value maps the meta key through [FeedbackStatusX.fromWire].
  List<({String label, FeedbackStatus value})> _statusPills() {
    final meta = ref.watch(feedbackMetaProvider).value;
    if (meta != null && meta.statuses.isNotEmpty) {
      return [
        for (final s in meta.statuses)
          (label: s.label, value: FeedbackStatusX.fromWire(s.key)),
      ];
    }
    return [for (final s in FeedbackStatus.values) (label: s.label, value: s)];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final view = ref.watch(feedbackViewProvider);
    final sort = ref.watch(feedbackSortProvider);
    final statusFilter = ref.watch(feedbackStatusFilterProvider);
    final postsAsync = ref.watch(feedbackPostsProvider);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // The floating action sits a little above the home indicator; the content
    // scrolls under it, so it keeps that much clear at its end.
    final actionBottom = safeBottom + 8;
    final contentBottom = actionBottom + 50 + 24;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const CircleBackButton(),
                      const SizedBox(width: 12),
                      Text(
                        'Feedback',
                        style: AppText.sans(size: 22, weight: FontWeight.w800, color: colors.text),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ViewToggle(
                    view: view,
                    onSelect: (v) => ref.read(feedbackViewProvider.notifier).set(v),
                  ),
                ),
                const SizedBox(height: 11),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: _search,
                          hasQuery: _hasText,
                          onChanged: _onSearchChanged,
                          onClear: _clearSearch,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SortButton(sort: sort, onTap: () => unawaited(_pickSort())),
                    ],
                  ),
                ),
                if (view == FeedbackView.list) ...[
                  const SizedBox(height: 6),
                  // 36 chips with 4 of room either side for their shadow.
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      children: [
                        _StatusChip(
                          label: 'All',
                          selected: statusFilter == null,
                          onTap: () => ref.read(feedbackStatusFilterProvider.notifier).set(null),
                        ),
                        for (final status in _statusPills())
                          _StatusChip(
                            label: status.label,
                            dot: status.value.color(colors),
                            selected: statusFilter == status.value,
                            onTap: () => ref
                                .read(feedbackStatusFilterProvider.notifier)
                                .set(statusFilter == status.value ? null : status.value),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const SizedBox(height: 10),
                Expanded(
                  child: postsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5),
                    ),
                    error: (error, _) => Padding(
                      padding: EdgeInsets.only(bottom: contentBottom),
                      child: _BoardError(
                        error: error,
                        onRetry: () => ref.invalidate(feedbackPostsProvider),
                      ),
                    ),
                    data: (posts) => view == FeedbackView.list
                        ? _ListBody(
                            posts: posts,
                            bottomInset: contentBottom,
                            onOpen: _open,
                            onVote: _vote,
                            onLoadMore: () => unawaited(
                              ref.read(feedbackPostsProvider.notifier).loadMore(),
                            ),
                          )
                        : _BoardBody(
                            posts: posts,
                            bottomInset: contentBottom,
                            onOpen: _open,
                            onVote: _vote,
                          ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: actionBottom,
            child: _MakeSuggestionButton(onTap: () => unawaited(_suggest())),
          ),
        ],
      ),
    );
  }
}

/// The scrolling list view: intro card, count eyebrow, suggestion cards — or
/// the empty state, centred in the room above the floating action.
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.posts,
    required this.bottomInset,
    required this.onOpen,
    required this.onVote,
    required this.onLoadMore,
  });

  final List<FeedbackPost> posts;
  final double bottomInset;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;

  /// Called when the list is scrolled near the bottom, to fetch the next page.
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final list = NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) onLoadMore();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _IntroCard(),
                const SizedBox(height: 16),
                Text(
                  'SUGGESTIONS (${posts.length})',
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w800,
                    letterSpacing: AppText.em(0.1, 12),
                    color: colors.textDim,
                  ),
                ),
                const SizedBox(height: 9),
              ]),
            ),
          ),
          if (posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(36, 0, 36, bottomInset),
                child: const _EmptyList(),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FeedbackPostCard(
                      post: posts[i],
                      onTap: () => onOpen(posts[i]),
                      onVote: () => onVote(posts[i]),
                    ),
                  ),
                  childCount: posts.length,
                ),
              ),
            ),
        ],
      ),
    );
    if (posts.isEmpty) return list;
    // FB_FADE: the cards fade out over the last stretch, under the action.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final h = bounds.height;
        final solid = h <= 0 ? 1.0 : ((h - bottomInset + 14) / h).clamp(0.0, 1.0);
        final clear = h <= 0 ? 1.0 : ((h - bottomInset + 30) / h).clamp(solid, 1.0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.black, Colors.black, Colors.transparent, Colors.transparent],
          stops: [0, solid, clear, 1],
        ).createShader(bounds);
      },
      child: list,
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Ic('search', size: 34, color: Color(0xFFD6D2CA)),
        const SizedBox(height: 8),
        Text(
          'No suggestions match',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
        ),
        const SizedBox(height: 6),
        Text(
          'Try a different search or filter, or make the first suggestion.',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.5, color: colors.textMed),
        ),
      ],
    );
  }
}

/// The kanban view: one horizontally-scrolling column per status.
class _BoardBody extends StatelessWidget {
  const _BoardBody({
    required this.posts,
    required this.bottomInset,
    required this.onOpen,
    required this.onVote,
  });

  final List<FeedbackPost> posts;
  final double bottomInset;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      children: [
        for (final status in FeedbackStatus.values)
          _BoardColumn(
            status: status,
            posts: [
              for (final p in posts)
                if (p.status == status) p,
            ],
            colors: colors,
            bottomInset: bottomInset,
            onOpen: onOpen,
            onVote: onVote,
          ),
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  const _BoardColumn({
    required this.status,
    required this.posts,
    required this.colors,
    required this.bottomInset,
    required this.onOpen,
    required this.onVote,
  });

  final FeedbackStatus status;
  final List<FeedbackPost> posts;
  final AppColors colors;
  final double bottomInset;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: colors.hilite,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: status.color(colors), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${posts.length}',
                  style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: posts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 120),
                    child: Text(
                      'Nothing here yet',
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textDim),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    children: [
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BoardPostCard(
                            post: post,
                            onTap: () => onOpen(post),
                            onVote: () => onVote(post),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// What the board is for, plus research + bug-report links (v11 promo banner).
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final link = AppText.sans(size: 15, weight: FontWeight.w800, color: colors.accent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdaMascot(size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  "We'd love to hear your ideas. Suggest features and upvote what matters to you.",
                  style: AppText.sans(size: 15, height: 1.45, color: colors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(
                    openExternal(context, Uri.parse('https://www.aqademiq.com/support')),
                  ),
                  child: Text('Join user research →', style: link),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(
                  openExternal(context, Uri.parse('mailto:support@aqademiq.com?subject=Bug report')),
                ),
                child: Text('Found a bug?', style: link),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// List | Board toggle (v11: two halves, radius 12, accent-soft when chosen).
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onSelect});

  final FeedbackView view;
  final ValueChanged<FeedbackView> onSelect;

  static const List<(FeedbackView, String, String)> _options = [
    (FeedbackView.list, 'view_agenda', 'List'),
    (FeedbackView.board, 'view_week', 'Board'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final (value, icon, label) in _options) ...[
          if (value != _options.first.$1) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: view == value,
              child: GestureDetector(
                onTap: () => onSelect(value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: view == value ? colors.accentSoft : colors.hilite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: view == value ? colors.accent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Ic(icon, size: 20, color: view == value ? colors.accent : colors.textMed),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: AppText.sans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: view == value ? colors.accent : colors.textMed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The 44 search pill: white, shadow, a 20 glyph and 17 text.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        children: [
          Ic('search', size: 20, color: colors.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text),
              cursorColor: colors.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search suggestions',
                hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (hasQuery)
            Semantics(
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(child: Ic('close', size: 18, color: colors.textDim)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One pill in the status-filter row (v11 `FeedChip`): 36 high, ink when
/// chosen, white with the card shadow otherwise.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          padding: dot != null ? const EdgeInsets.fromLTRB(12, 0, 14, 0) : const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.ink : colors.surface,
            borderRadius: BorderRadius.circular(100),
            boxShadow: selected ? null : colors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.sans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: selected ? Colors.white : colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 44 sort pill: the sort glyph and "Top" / "New".
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onTap});

  final FeedbackSort sort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: 'Sort suggestions',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(13, 0, 15, 0),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: colors.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ic('sort', size: 19, color: colors.text),
              const SizedBox(width: 5),
              Text(
                sort == FeedbackSort.top ? 'Top' : 'New',
                style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Make a suggestion", floating over both views (v11 `MakeSuggestionBtn`).
class _MakeSuggestionButton extends StatelessWidget {
  const _MakeSuggestionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: colors.ink,
            borderRadius: BorderRadius.circular(100),
            boxShadow: const [BoxShadow(color: Color(0x38000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Ic('add', size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Make a suggestion',
                style: AppText.sans(size: 17, weight: FontWeight.w800, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardError extends StatelessWidget {
  const _BoardError({required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A 401 is not a connectivity problem — telling someone to "try again" when
    // they simply are not signed in sends them round in circles.
    final needsAuth = error is AuthFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (needsAuth)
              Ic('lock', size: 40, color: colors.textDim)
            else
              AppIcon(Icons.cloud_off_rounded, size: 40, color: colors.textDim),
            const SizedBox(height: 12),
            Text(
              needsAuth ? 'Sign in to see the board' : "Couldn't load the board",
              textAlign: TextAlign.center,
              style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
            ),
            if (needsAuth) ...[
              const SizedBox(height: 6),
              Text(
                'Suggestions and votes are tied to your account.',
                textAlign: TextAlign.center,
                style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.textMed),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: needsAuth ? () => context.push(Routes.signin) : onRetry,
              child: Text(
                needsAuth ? 'Sign in' : 'Try again',
                style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
