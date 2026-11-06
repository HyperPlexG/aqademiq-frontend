import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/feedback_post.dart';
import '../../../../shared/widgets/ic.dart';

/// The v11 board's cool grey for a status that is not moving (FeedbackBody).
const Color kFeedbackStatusGrey = Color(0xFF9AA3B2);

/// Board-column / badge styling for each [FeedbackStatus].
extension FeedbackStatusUi on FeedbackStatus {
  /// Wording matches `feedback_statuses.label` on the server, so a post's badge
  /// reads the same as the admin console that set it.
  String get label => switch (this) {
        FeedbackStatus.underReview => 'Under review',
        FeedbackStatus.planned => 'Planned',
        FeedbackStatus.inProgress => 'In progress',
        FeedbackStatus.shipped => 'Shipped',
        FeedbackStatus.declined => 'Declined',
      };

  /// Status dot. Planned / In progress / Shipped keep the semantic tokens that
  /// match `feedback_statuses.color` on the server (#6b5cf0, #e8a430,
  /// #2a9d6b); Under review takes the v11 board's cool grey.
  Color color(AppColors colors) => switch (this) {
        FeedbackStatus.underReview => kFeedbackStatusGrey,
        FeedbackStatus.planned => colors.accent,
        FeedbackStatus.inProgress => colors.warn,
        FeedbackStatus.shipped => colors.success,
        FeedbackStatus.declined => colors.textDim,
      };
}

/// Chip styling for each [FeedbackCategory] (v11 `FB_KIND`).
extension FeedbackCategoryUi on FeedbackCategory {
  String get label => switch (this) {
        FeedbackCategory.feature => 'Feature',
        FeedbackCategory.improvement => 'Improvement',
        FeedbackCategory.bug => 'Bug',
      };

  /// The design name of the category's glyph, for [Ic].
  String get icon => switch (this) {
        FeedbackCategory.feature => 'lightbulb',
        FeedbackCategory.improvement => 'tune',
        FeedbackCategory.bug => 'bug_report',
      };

  /// The chip's ink.
  Color color(AppColors colors) => switch (this) {
        FeedbackCategory.feature => colors.accent,
        FeedbackCategory.improvement => const Color(0xFF2A76B3),
        FeedbackCategory.bug => colors.danger,
      };

  /// The chip's tint behind that ink.
  Color tint(AppColors colors) => switch (this) {
        FeedbackCategory.feature => colors.accentSoft,
        FeedbackCategory.improvement => const Color(0x245CBBFF),
        FeedbackCategory.bug => colors.danger.alpha8(0x1C),
      };
}

/// "2w ago" / "just now" caption for posts and comments.
String feedbackAgo(DateTime d) {
  final ago = AppDate.ago(d);
  return ago == 'now' ? 'just now' : '$ago ago';
}

/// The vote box (v11 `FeedCard`): 46 × 30, radius 10, a hairline border that
/// turns accent once voted, the up chevron and the count. [compact] is the
/// board-card form.
class VotePill extends StatelessWidget {
  const VotePill({
    super.key,
    required this.votes,
    required this.voted,
    this.onTap,
    this.compact = false,
  });

  final int votes;
  final bool voted;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      toggled: voted,
      label: voted ? 'Voted, $votes votes' : 'Vote, $votes votes',
      excludeSemantics: true,
      // excludeSemantics drops the GestureDetector's own tap action, so the
      // screen-reader tap has to be given here.
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: compact ? 28 : 30,
          constraints: BoxConstraints(minWidth: compact ? 42 : 46),
          padding: const EdgeInsets.fromLTRB(2, 0, 6, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: voted ? colors.accent : colors.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Ic('chevron_up', size: compact ? 18 : 20, color: voted ? colors.accent : colors.textMed),
              Text(
                '$votes',
                style: AppText.sans(
                  size: compact ? 15 : 17,
                  weight: FontWeight.w800,
                  color: colors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status indicator: a dot in the status colour and the label (15/700, muted)
/// on cards, or a tinted pill ([tinted]) on the detail screen.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.tinted = false});

  final FeedbackStatus status;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = status.color(colors);
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
    final label = Flexible(
      child: Text(
        status.label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: AppText.sans(
          size: 15,
          weight: FontWeight.w700,
          color: tinted ? colors.text : colors.textMed,
        ),
      ),
    );
    if (!tinted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [dot, const SizedBox(width: 6), label],
      );
    }
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: c.alpha8(0x1C),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [dot, const SizedBox(width: 6), label],
      ),
    );
  }
}

/// The tinted category chip (v11 `FeedCard`: radius 8, 15/800, a 16 glyph).
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final FeedbackCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = category.color(colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: category.tint(colors),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ic(category.icon, size: 16, color: ink),
          const SizedBox(width: 4),
          Text(
            category.label,
            maxLines: 1,
            softWrap: false,
            style: AppText.sans(size: 15, weight: FontWeight.w800, color: ink),
          ),
        ],
      ),
    );
  }
}

/// A suggestion in the list view (v11 `FeedCard`): title + `#number`, a
/// two-line excerpt, status / comments / category, the vote box on the right.
class FeedbackPostCard extends StatelessWidget {
  const FeedbackPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onVote,
  });

  final FeedbackPost post;
  final VoidCallback? onTap;
  final VoidCallback? onVote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: colors.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(15, 13, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: post.title,
                      children: [
                        TextSpan(
                          text: ' #${post.number}',
                          style: AppText.sans(size: 17, weight: FontWeight.w700, height: 1.25, color: colors.textDim),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 17, weight: FontWeight.w800, height: 1.25, color: colors.text),
                  ),
                  if (post.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.42, color: colors.textMed),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // The chip keeps its width on the right; when the line runs
                  // short it is the status label that gives way.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: StatusBadge(status: post.status)),
                            const SizedBox(width: 12),
                            _CommentCount(count: post.commentCount),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CategoryChip(category: post.category),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            VotePill(votes: post.votes, voted: post.hasVoted, onTap: onVote),
          ],
        ),
      ),
    );
  }
}

/// The speech bubble and the reply count (15/700, dim).
class _CommentCount extends StatelessWidget {
  const _CommentCount({required this.count, this.size = 15});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ic('chat_bubble_outline', size: size + 3, color: colors.textDim),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppText.sans(size: size, weight: FontWeight.w700, color: colors.textDim),
        ),
      ],
    );
  }
}

/// Compact card used inside the kanban board columns (200 wide).
class BoardPostCard extends StatelessWidget {
  const BoardPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onVote,
  });

  final FeedbackPost post;
  final VoidCallback? onTap;
  final VoidCallback? onVote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: colors.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 15, weight: FontWeight.w800, height: 1.3, color: colors.text),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                VotePill(
                  votes: post.votes,
                  voted: post.hasVoted,
                  onTap: onVote,
                  compact: true,
                ),
                const Spacer(),
                if (post.commentCount > 0) ...[
                  _CommentCount(count: post.commentCount, size: 13),
                  const SizedBox(width: 8),
                ],
                Text(
                  '#${post.number}',
                  style: AppText.sans(size: 13, weight: FontWeight.w700, color: colors.textDim),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
