import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/launch_external.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/feedback_post.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/feedback_providers.dart';
import 'sheets/create_account_prompt.dart';
import 'sheets/feedback_sort_sheet.dart';
import 'sheets/new_suggestion_sheet.dart';
import 'widgets/feedback_bits.dart';

/// The Tiimo-style feedback board: community suggestions with votes and
/// statuses, a List / Board (kanban) toggle, search, status filters and
/// sorting. Entry: Settings → About → "Feedback & suggestions".
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

  /// One-tap recovery from a filtered-to-nothing result.
  void _clearAllFilters() {
    _clearSearch();
    ref.read(feedbackStatusFilterProvider.notifier).set(null);
  }

  /// Guests may browse but not write — prompt sign-up at the point of action
  /// (FEEDBACK_BOARD_INTEGRATION.md §"Guest rule"). Returns true if the caller
  /// may proceed.
  bool _requireAccount(String reason) {
    if (!ref.read(isGuestProvider)) return true;
    unawaited(showCreateAccountPrompt(context, reason: reason));
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
          unawaited(showCreateAccountPrompt(context, reason: 'post a suggestion'));
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
    // Use the APPLIED search (what the posts provider actually fetched with),
    // not the raw field text, so "filtered to nothing" vs "truly empty" is
    // decided on the same inputs as the data. Board view bypasses the status
    // filter (see feedbackPostsProvider), so only search counts there.
    final appliedSearch = ref.watch(feedbackSearchProvider).trim();
    final isFiltered = appliedSearch.isNotEmpty ||
        (view == FeedbackView.list && statusFilter != null);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  const _BackCircle(),
                  const SizedBox(width: 12),
                  Text(
                    'Feedback',
                    style: AppText.sans(
                      size: 20,
                      weight: FontWeight.w800,
                      color: colors.text,
                    ),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            if (view == FeedbackView.list) ...[
              SizedBox(
                height: 30,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _StatusChip(
                      label: 'All',
                      selected: statusFilter == null,
                      onTap: () => ref
                          .read(feedbackStatusFilterProvider.notifier)
                          .set(null),
                    ),
                    for (final status in _statusPills())
                      _StatusChip(
                        label: status.label,
                        dot: status.value.color(colors),
                        selected: statusFilter == status.value,
                        onTap: () => ref
                            .read(feedbackStatusFilterProvider.notifier)
                            .set(statusFilter == status.value
                                ? null
                                : status.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: postsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (error, _) => _BoardError(
                  error: error,
                  onRetry: () => ref.invalidate(feedbackPostsProvider),
                ),
                data: (posts) => view == FeedbackView.list
                    ? _ListBody(
                        posts: posts,
                        isFiltered: isFiltered,
                        onOpen: _open,
                        onVote: _vote,
                        onClearFilters: _clearAllFilters,
                        onLoadMore: () => unawaited(
                          ref.read(feedbackPostsProvider.notifier).loadMore(),
                        ),
                      )
                    : _BoardBody(
                        posts: posts,
                        isFiltered: isFiltered,
                        onOpen: _open,
                        onVote: _vote,
                        onClearFilters: _clearAllFilters,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: PrimaryButton(
                label: 'Make a suggestion',
                icon: Icons.add,
                onPressed: () => unawaited(_suggest()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling list view: intro card, count eyebrow, suggestion cards.
class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.posts,
    required this.isFiltered,
    required this.onOpen,
    required this.onVote,
    required this.onClearFilters,
    required this.onLoadMore,
  });

  final List<FeedbackPost> posts;

  /// Whether a search/status filter produced this (possibly empty) list —
  /// decides which empty state to show.
  final bool isFiltered;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;
  final VoidCallback onClearFilters;

  /// Called when the list is scrolled near the bottom, to fetch the next page.
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) onLoadMore();
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        children: [
        const _IntroCard(),
        const SizedBox(height: 14),
        Text(
          'SUGGESTIONS (${posts.length})',
          style: AppText.sans(
            size: 9,
            weight: FontWeight.w800,
            letterSpacing: AppText.em(0.12, 9),
            color: colors.textDim,
          ),
        ),
        const SizedBox(height: 8),
        // Filtered-to-nothing offers a one-tap way back; a genuinely empty
        // board invites the first suggestion (the pinned button below is the
        // CTA, so neither variant adds its own).
        if (posts.isEmpty && isFiltered)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyState.compact(
              title: 'No suggestions match',
              subtitle: 'Nothing fits that search or filter — loosen it up, or suggest it yourself.',
              expr: AdaExpr.meh,
              ctaLabel: 'Clear filters',
              ctaIcon: Icons.close,
              onCta: onClearFilters,
            ),
          )
        else if (posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              title: 'Uhh... nothing here yet',
              subtitle: 'Be the first — tell us what Aqademiq should build next. We read everything.',
              sparkles: true,
            ),
          )
        else
          for (final post in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FeedbackPostCard(
                post: post,
                onTap: () => onOpen(post),
                onVote: () => onVote(post),
              ),
            ),
        ],
      ),
    );
  }
}

/// The kanban view: one horizontally-scrolling column per status.
class _BoardBody extends StatelessWidget {
  const _BoardBody({
    required this.posts,
    required this.isFiltered,
    required this.onOpen,
    required this.onVote,
    required this.onClearFilters,
  });

  final List<FeedbackPost> posts;

  /// Whether a search query produced this (possibly empty) board — the status
  /// filter doesn't apply in board view.
  final bool isFiltered;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A wall of six empty columns says nothing — greet instead (the pinned
    // "Make a suggestion" button below stays the CTA for the unfiltered case).
    if (posts.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: isFiltered
              ? EmptyState.compact(
                  title: 'No suggestions match',
                  subtitle: 'Nothing fits that search — loosen it up.',
                  expr: AdaExpr.meh,
                  ctaLabel: 'Clear search',
                  ctaIcon: Icons.close,
                  onCta: onClearFilters,
                )
              : const EmptyState(
                  title: 'The board is a blank canvas',
                  subtitle: 'Suggestions land here once ideas start rolling in — yours could be first.',
                  expr: AdaExpr.smile,
                ),
        ),
      );
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 2, 6, 12),
      children: [
        for (final status in FeedbackStatus.values)
          _BoardColumn(
            status: status,
            posts: [
              for (final p in posts)
                if (p.status == status) p,
            ],
            colors: colors,
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
    required this.onOpen,
    required this.onVote,
  });

  final FeedbackStatus status;
  final List<FeedbackPost> posts;
  final AppColors colors;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: colors.hilite,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: status.color(colors),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(
                      size: 10.5,
                      weight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${posts.length}',
                  style: AppText.sans(
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: colors.textMed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Text(
                      'Nothing here yet',
                      style: AppText.sans(size: 10.5, color: colors.textDim),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
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

/// Tiimo-style intro: what the board is for, plus research + bug-report links.
class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.accent.alpha8(0x22), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AdaMascot(size: 26),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "We'd love to hear your ideas — suggest features and upvote what matters to you. We read everything.",
                  style: AppText.sans(
                    size: 10.5,
                    height: 1.4,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(
                  openExternal(
                    context,
                    Uri.parse('https://www.aqademiq.com/support'),
                  ),
                ),
                child: Text(
                  'Join user research →',
                  style: AppText.sans(
                    size: 10.5,
                    weight: FontWeight.w800,
                    color: colors.accent,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(
                  openExternal(
                    context,
                    Uri.parse('mailto:support@aqademiq.com?subject=Bug report'),
                  ),
                ),
                child: Text(
                  'Found a bug?',
                  style: AppText.sans(
                    size: 10.5,
                    weight: FontWeight.w800,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// List | Board segmented toggle (the app's _TermSelector idiom).
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onSelect});

  final FeedbackView view;
  final ValueChanged<FeedbackView> onSelect;

  static const List<(FeedbackView, IconData, String)> _options = [
    (FeedbackView.list, Icons.view_agenda_outlined, 'List'),
    (FeedbackView.board, Icons.view_kanban_outlined, 'Board'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final (value, icon, label) in _options) ...[
          if (value != _options.first.$1) const SizedBox(width: 7),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: view == value ? colors.accentSoft : colors.hilite,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: view == value ? colors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: view == value ? colors.accent : colors.textMed,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: AppText.sans(
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: view == value ? colors.accent : colors.textMed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: colors.textDim),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppText.sans(size: 12.5, color: colors.text),
              cursorColor: colors.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search suggestions',
                hintStyle: AppText.sans(size: 12.5, color: colors.textDim),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (hasQuery)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close, size: 14, color: colors.textDim),
            ),
        ],
      ),
    );
  }
}

/// One pill in the status-filter row. Selected = ink fill + white text.
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.ink : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
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
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppText.sans(
                size: 11,
                weight: FontWeight.w800,
                color: selected ? Colors.white : colors.textMed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onTap});

  final FeedbackSort sort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: colors.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 15, color: colors.text),
            const SizedBox(width: 5),
            Text(
              sort == FeedbackSort.top ? 'Top' : 'New',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w800,
                color: colors.text,
              ),
            ),
          ],
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
            Icon(
              needsAuth ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
              size: 40,
              color: colors.textDim,
            ),
            const SizedBox(height: 12),
            Text(
              needsAuth ? 'Sign in to see the board' : "Couldn't load the board",
              textAlign: TextAlign.center,
              style: AppText.sans(
                size: 14,
                weight: FontWeight.w800,
                color: colors.text,
              ),
            ),
            if (needsAuth) ...[
              const SizedBox(height: 6),
              Text(
                'Suggestions and votes are tied to your account.',
                textAlign: TextAlign.center,
                style: AppText.sans(size: 11.5, height: 1.4, color: colors.textMed),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: needsAuth
                  ? () => context.push(Routes.signin)
                  : onRetry,
              child: Text(needsAuth ? 'Sign in' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 38px circular back button (same recipe as the settings scaffold's).
class _BackCircle extends StatelessWidget {
  const _BackCircle();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: colors.cardShadow,
        ),
        child: Icon(Icons.chevron_left, size: 21, color: colors.text),
      ),
    );
  }
}
