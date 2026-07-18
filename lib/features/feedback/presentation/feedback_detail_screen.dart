import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/feedback_post.dart';
import '../providers/feedback_providers.dart';
import 'widgets/feedback_bits.dart';

/// A single suggestion: full text, vote control, and the comment thread with
/// a composer pinned to the bottom.
class FeedbackDetailScreen extends ConsumerStatefulWidget {
  const FeedbackDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<FeedbackDetailScreen> createState() =>
      _FeedbackDetailScreenState();
}

class _FeedbackDetailScreenState extends ConsumerState<FeedbackDetailScreen> {
  final TextEditingController _comment = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Normally set by the board before pushing; re-assert here so the comments
    // provider stays pointed at this post after a hot restart / deep link.
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        ref.read(selectedFeedbackPostIdProvider.notifier).select(widget.id);
      }),
    );
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await ref.read(feedbackCommentsProvider.notifier).add(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _comment.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not post your comment. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final postsAsync = ref.watch(feedbackPostsProvider);
    final post =
        postsAsync.value?.where((p) => p.id == widget.id).firstOrNull;

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
                    post == null ? 'Suggestion' : 'Suggestion #${post.number}',
                    style: AppText.sans(
                      size: 20,
                      weight: FontWeight.w800,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: postsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 40,
                        color: colors.textDim,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Couldn't load this suggestion",
                        style: AppText.sans(
                          size: 14,
                          weight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(feedbackPostsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (_) => post == null
                    ? Center(
                        child: Text(
                          'This suggestion is gone.',
                          style: AppText.sans(size: 13, color: colors.textMed),
                        ),
                      )
                    : _PostBody(post: post),
              ),
            ),
            if (post != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.rowInput),
                          boxShadow: colors.cardShadow,
                        ),
                        padding: const EdgeInsets.fromLTRB(15, 4, 12, 4),
                        child: TextField(
                          controller: _comment,
                          minLines: 1,
                          maxLines: 4,
                          style: AppText.sans(size: 13, color: colors.text),
                          cursorColor: colors.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'Add a comment…',
                            hintStyle: AppText.sans(
                              size: 13,
                              color: colors.textDim,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => unawaited(_send()),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.ink,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostBody extends ConsumerWidget {
  const _PostBody({required this.post});

  final FeedbackPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final commentsAsync = ref.watch(feedbackCommentsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
      children: [
        Row(
          children: [
            StatusBadge(status: post.status, tinted: true),
            const SizedBox(width: 7),
            CategoryChip(category: post.category),
            const Spacer(),
            Text(
              feedbackAgo(post.createdAt),
              style: AppText.sans(
                size: 10,
                weight: FontWeight.w600,
                color: colors.textDim,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          post.title,
          style: AppText.sans(
            size: 19,
            weight: FontWeight.w800,
            height: 1.3,
            color: colors.text,
          ),
        ),
        if (post.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.body,
            style: AppText.sans(
              size: 12.5,
              height: 1.6,
              weight: FontWeight.w500,
              color: colors.textMed,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            VotePill(
              votes: post.votes,
              voted: post.hasVoted,
              onTap: () => unawaited(
                ref.read(feedbackPostsProvider.notifier).toggleVote(post),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              post.votes == 1 ? '1 vote' : '${post.votes} votes',
              style: AppText.sans(
                size: 11.5,
                weight: FontWeight.w700,
                color: colors.textMed,
              ),
            ),
            const Spacer(),
            if (post.author.isNotEmpty)
              Text(
                'by ${post.author}',
                style: AppText.sans(size: 10.5, color: colors.textDim),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'COMMENTS (${post.commentCount})',
          style: AppText.sans(
            size: 9,
            weight: FontWeight.w800,
            letterSpacing: AppText.em(0.12, 9),
            color: colors.textDim,
          ),
        ),
        const SizedBox(height: 10),
        commentsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: colors.accent,
                strokeWidth: 2.5,
              ),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  'Could not load comments',
                  style: AppText.sans(size: 12, color: colors.textMed),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(feedbackCommentsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (comments) => comments.isEmpty
              ? Text(
                  'No comments yet — start the discussion.',
                  style: AppText.sans(
                    size: 11.5,
                    height: 1.5,
                    color: colors.textMed,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final comment in comments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CommentCard(comment: comment),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final FeedbackComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: colors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  comment.author,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(
                    size: 11.5,
                    weight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              if (comment.isTeam) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.accent.alpha8(0x1C),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'TEAM',
                    style: AppText.sans(
                      size: 8,
                      weight: FontWeight.w800,
                      letterSpacing: AppText.em(0.1, 8),
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                feedbackAgo(comment.createdAt),
                style: AppText.sans(size: 9.5, color: colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            comment.body,
            style: AppText.sans(
              size: 11.5,
              height: 1.5,
              weight: FontWeight.w500,
              color: colors.text,
            ),
          ),
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
