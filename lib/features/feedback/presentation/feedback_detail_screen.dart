import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/feedback_post.dart';
import '../../../shared/icons/app_icon.dart';
import '../../../shared/widgets/circle_back_button.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import '../providers/feedback_providers.dart';
import 'sheets/create_account_prompt.dart';
import 'widgets/feedback_bits.dart';

/// A single suggestion: full text, vote control, and the comment thread with
/// a composer pinned to the bottom. No frame of its own in v11; it speaks the
/// board's language (22 title, 17 / 15 text, 44 controls).
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
  bool _locked = false;

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
    if (text.isEmpty || _sending || _locked) return;
    // Guests may read but not comment — prompt sign-up at the point of action.
    if (ref.read(isGuestProvider)) {
      unawaited(showCreateAccountPrompt(context, ref, reason: 'comment'));
      return;
    }
    setState(() => _sending = true);
    final outcome = await ref.read(feedbackCommentsProvider.notifier).add(text);
    if (!mounted) return;
    setState(() => _sending = false);
    switch (outcome) {
      case AddCommentOutcome.ok:
        _comment.clear();
        FocusScope.of(context).unfocus();
      case AddCommentOutcome.locked:
        // The thread was locked — disable the composer and tell the user.
        setState(() => _locked = true);
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This thread is locked.')),
        );
      case AddCommentOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not post your comment. Try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isGuest = ref.watch(isGuestProvider);
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  const CircleBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      post == null ? 'Suggestion' : 'Suggestion #${post.number}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 22, weight: FontWeight.w800, color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: postsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5),
                ),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(Icons.cloud_off_rounded, size: 40, color: colors.textDim),
                      const SizedBox(height: 12),
                      Text(
                        "Couldn't load this suggestion",
                        style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref.invalidate(feedbackPostsProvider),
                        child: Text(
                          'Try again',
                          style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (_) => post == null
                    ? Center(
                        child: Text(
                          'This suggestion is gone.',
                          style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
                        ),
                      )
                    : _PostBody(post: post),
              ),
            ),
            if (post != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _buildComposer(colors, isGuest: isGuest),
              ),
          ],
        ),
      ),
    );
  }

  /// The bottom bar: a "Create an account to comment" button for guests, a
  /// locked notice when the thread is locked (a comment POST returned 409), or
  /// the comment composer otherwise (INTEGRATION.md §4 step 4).
  Widget _buildComposer(AppColors colors, {required bool isGuest}) {
    if (isGuest) {
      return PrimaryButton(
        label: 'Create an account to comment',
        onPressed: () =>
            unawaited(showCreateAccountPrompt(context, ref, reason: 'comment')),
      );
    }
    if (_locked) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.hilite,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic('lock', size: 18, color: colors.textMed),
            const SizedBox(width: 6),
            Text(
              'This thread is locked',
              style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.textMed),
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: colors.cardShadow,
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 14, 0),
            child: TextField(
              controller: _comment,
              minLines: 1,
              maxLines: 4,
              style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text),
              cursorColor: colors.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Add a comment…',
                hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Post comment',
          child: GestureDetector(
            onTap: () => unawaited(_send()),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.ink, shape: BoxShape.circle),
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Ic('arrow_upward', size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
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
            Expanded(
              child: Row(
                children: [
                  Flexible(child: StatusBadge(status: post.status, tinted: true)),
                  const SizedBox(width: 8),
                  CategoryChip(category: post.category),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              feedbackAgo(post.createdAt),
              style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          post.title,
          style: AppText.sans(size: 22, weight: FontWeight.w800, height: 1.3, color: colors.text),
        ),
        if (post.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.body,
            style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            VotePill(
              votes: post.votes,
              voted: post.hasVoted,
              onTap: () {
                if (ref.read(isGuestProvider)) {
                  unawaited(
                    showCreateAccountPrompt(
                      context,
                      ref,
                      reason: 'vote on suggestions',
                    ),
                  );
                  return;
                }
                unawaited(
                  ref.read(feedbackPostsProvider.notifier).toggleVote(post),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                post.votes == 1 ? '1 vote' : '${post.votes} votes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.textMed),
              ),
            ),
            const SizedBox(width: 10),
            const _FollowPill(),
          ],
        ),
        if (post.author.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'by ${post.author}',
            style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'COMMENTS (${post.commentCount})',
          style: AppText.sans(
            size: 12,
            weight: FontWeight.w800,
            letterSpacing: AppText.em(0.1, 12),
            color: colors.textDim,
          ),
        ),
        const SizedBox(height: 9),
        commentsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  'Could not load comments',
                  style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(feedbackCommentsProvider),
                  child: Text(
                    'Try again',
                    style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
          data: (comments) => comments.isEmpty
              ? Text(
                  'No comments yet — start the discussion.',
                  style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.5, color: colors.textMed),
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

/// Follow / Following: followers get an email when the post gets a reply or
/// changes status. Posting or commenting follows a post automatically.
class _FollowPill extends ConsumerWidget {
  const _FollowPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final following = ref.watch(feedbackSubscriptionProvider).value ?? false;
    Future<void> toggle() async {
      if (ref.read(isGuestProvider)) {
        unawaited(showCreateAccountPrompt(context, ref, reason: 'follow suggestions'));
        return;
      }
      final ok = await ref.read(feedbackSubscriptionProvider.notifier).toggle();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update that. Try again.")),
        );
      }
    }

    return Semantics(
      button: true,
      toggled: following,
      label: following ? 'Following this suggestion' : 'Follow this suggestion',
      excludeSemantics: true,
      // excludeSemantics drops the GestureDetector's own tap action, so the
      // screen-reader tap has to be given here.
      onTap: () => unawaited(toggle()),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(toggle()),
        child: Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
          decoration: BoxDecoration(
            color: following ? colors.accentSoft : colors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: following ? colors.accent : colors.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ic(
                following ? 'notifications:fill' : 'notifications',
                size: 18,
                color: following ? colors.accent : colors.textMed,
              ),
              const SizedBox(width: 6),
              Text(
                following ? 'Following' : 'Follow',
                style: AppText.sans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: following ? colors.accent : colors.textMed,
                ),
              ),
            ],
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: colors.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text),
                      ),
                    ),
                    if (comment.isTeam) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'TEAM',
                          style: AppText.sans(
                            size: 11,
                            weight: FontWeight.w800,
                            letterSpacing: AppText.em(0.08, 11),
                            color: colors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                feedbackAgo(comment.createdAt),
                style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            comment.body,
            style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.text),
          ),
        ],
      ),
    );
  }
}
