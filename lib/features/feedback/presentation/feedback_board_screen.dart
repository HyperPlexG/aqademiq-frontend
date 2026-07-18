import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/launch_external.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/feedback_post.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/feedback_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(feedbackSearchProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(FeedbackPost post) {
    ref.read(selectedFeedbackPostIdProvider.notifier).select(post.id);
    unawaited(context.push(Routes.feedbackPost(post.id)));
  }

  Future<void> _suggest() async {
    var draft = await showNewSuggestionSheet(context);
    while (true) {
      if (draft == null || !mounted) return;
      final created = await ref.read(feedbackPostsProvider.notifier).submit(
            title: draft.title,
            body: draft.body,
            category: draft.category,
          );
      if (!mounted) return;
      if (created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks! Your suggestion is on the board.'),
          ),
        );
        return;
      }
      // Keep the draft: reopen the sheet prefilled so nothing typed is lost.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not share your suggestion. Try again.'),
        ),
      );
      draft = await showNewSuggestionSheet(context, initial: draft);
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

  /// Search + status filter + sort applied to the raw post list.
  List<FeedbackPost> _visible(
    List<FeedbackPost> posts, {
    required String query,
    required FeedbackStatus? status,
    required FeedbackSort sort,
  }) {
    final q = query.trim().toLowerCase();
    final filtered = [
      for (final p in posts)
        if ((status == null || p.status == status) &&
            (q.isEmpty ||
                p.title.toLowerCase().contains(q) ||
                p.body.toLowerCase().contains(q)))
          p,
    ]..sort(
        (a, b) => switch (sort) {
          FeedbackSort.top => a.votes == b.votes
              ? b.createdAt.compareTo(a.createdAt)
              : b.votes.compareTo(a.votes),
          FeedbackSort.newest => b.createdAt.compareTo(a.createdAt),
        },
      );
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final view = ref.watch(feedbackViewProvider);
    final sort = ref.watch(feedbackSortProvider);
    final statusFilter = ref.watch(feedbackStatusFilterProvider);
    final query = ref.watch(feedbackSearchProvider);
    final postsAsync = ref.watch(feedbackPostsProvider);

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
                      hasQuery: query.isNotEmpty,
                      onChanged: (v) =>
                          ref.read(feedbackSearchProvider.notifier).set(v),
                      onClear: () {
                        _search.clear();
                        ref.read(feedbackSearchProvider.notifier).set('');
                      },
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
                    for (final status in FeedbackStatus.values)
                      _StatusChip(
                        label: status.label,
                        dot: status.color(colors),
                        selected: statusFilter == status,
                        onTap: () => ref
                            .read(feedbackStatusFilterProvider.notifier)
                            .set(statusFilter == status ? null : status),
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
                error: (_, _) => _BoardError(
                  onRetry: () => ref.invalidate(feedbackPostsProvider),
                ),
                data: (posts) => view == FeedbackView.list
                    ? _ListBody(
                        posts: _visible(
                          posts,
                          query: query,
                          status: statusFilter,
                          sort: sort,
                        ),
                        onOpen: _open,
                        onVote: (p) => unawaited(
                          ref
                              .read(feedbackPostsProvider.notifier)
                              .toggleVote(p),
                        ),
                      )
                    : _BoardBody(
                        posts: _visible(
                          posts,
                          query: query,
                          status: null,
                          sort: sort,
                        ),
                        onOpen: _open,
                        onVote: (p) => unawaited(
                          ref
                              .read(feedbackPostsProvider.notifier)
                              .toggleVote(p),
                        ),
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
    required this.onOpen,
    required this.onVote,
  });

  final List<FeedbackPost> posts;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
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
        if (posts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36),
            child: Column(
              children: [
                Icon(Icons.forum_outlined, size: 34, color: colors.textDim),
                const SizedBox(height: 10),
                Text(
                  'No suggestions match',
                  style: AppText.sans(
                    size: 13,
                    weight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try a different search or filter — or make the first suggestion.',
                  textAlign: TextAlign.center,
                  style: AppText.sans(
                    size: 11,
                    height: 1.5,
                    color: colors.textMed,
                  ),
                ),
              ],
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
    );
  }
}

/// The kanban view: one horizontally-scrolling column per status.
class _BoardBody extends StatelessWidget {
  const _BoardBody({
    required this.posts,
    required this.onOpen,
    required this.onVote,
  });

  final List<FeedbackPost> posts;
  final ValueChanged<FeedbackPost> onOpen;
  final ValueChanged<FeedbackPost> onVote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                    Uri.parse('https://aqademiq.app/research'),
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
                    Uri.parse('mailto:hello@aqademiq.app?subject=Bug report'),
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
  const _BoardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: colors.textDim),
          const SizedBox(height: 12),
          Text(
            "Couldn't load the board",
            style: AppText.sans(
              size: 14,
              weight: FontWeight.w800,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
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
