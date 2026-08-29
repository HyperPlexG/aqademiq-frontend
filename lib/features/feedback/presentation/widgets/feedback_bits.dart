import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/feedback_post.dart';

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

  /// Status accent — semantic tokens chosen to match `feedback_statuses.color`
  /// on the server (#777777, #6b5cf0, #e8a430, #2a9d6b, #c0c0c0) so the app and
  /// the board agree on what each state looks like.
  Color color(AppColors colors) => switch (this) {
        FeedbackStatus.underReview => colors.textMed,
        FeedbackStatus.planned => colors.accent,
        FeedbackStatus.inProgress => colors.warn,
        FeedbackStatus.shipped => colors.success,
        FeedbackStatus.declined => colors.textDim,
      };
}

/// Chip styling for each [FeedbackCategory].
extension FeedbackCategoryUi on FeedbackCategory {
  String get label => switch (this) {
        FeedbackCategory.feature => 'Feature',
        FeedbackCategory.improvement => 'Improvement',
        FeedbackCategory.bug => 'Bug',
      };

  IconData get icon => switch (this) {
        FeedbackCategory.feature => Icons.lightbulb_outline,
        FeedbackCategory.improvement => Icons.tune,
        FeedbackCategory.bug => Icons.bug_report_outlined,
      };

  Color color(AppColors colors) => switch (this) {
        FeedbackCategory.feature => colors.accent,
        FeedbackCategory.improvement => const Color(0xFF5CBBFF),
        FeedbackCategory.bug => colors.danger,
      };
}

/// "2w ago" / "just now" caption for posts and comments.
String feedbackAgo(DateTime d) {
  final ago = AppDate.ago(d);
  return ago == 'now' ? 'just now' : '$ago ago';
}

/// The ▲-vote control. Voted = accentSoft fill + accent border/text; not yet
/// voted = surface + hairline border. [compact] is the smaller board-card form.
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
    final fg = voted ? colors.accent : colors.textMed;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: compact
            ? const EdgeInsets.fromLTRB(5, 2, 9, 2)
            : const EdgeInsets.fromLTRB(6, 4, 11, 4),
        decoration: BoxDecoration(
          color: voted ? colors.accentSoft : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: voted ? colors.accent : colors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_drop_up, size: compact ? 16 : 20, color: fg),
            const SizedBox(width: 1),
            Text(
              '$votes',
              style: AppText.sans(
                size: compact ? 10.5 : 11.5,
                weight: FontWeight.w800,
                color: voted ? colors.accent : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status indicator: plain dot + colored label on cards, or a tinted pill
/// ([tinted]) on the detail screen.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.tinted = false});

  final FeedbackStatus status;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final c = status.color(context.colors);
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
        style: AppText.sans(size: 10, weight: FontWeight.w800, color: c),
      ),
    );
    if (!tinted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [dot, const SizedBox(width: 5), label],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.alpha8(0x1C),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [dot, const SizedBox(width: 5), label],
      ),
    );
  }
}

/// Tiny tinted category chip (GradeChip idiom: alpha-tinted bg, icon + w800
/// text in the category color).
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final FeedbackCategory category;

  @override
  Widget build(BuildContext context) {
    final c = category.color(context.colors);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.alpha8(0x1C),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 11, color: c),
          const SizedBox(width: 3),
          Text(
            category.label,
            style: AppText.sans(size: 10, weight: FontWeight.w800, color: c),
          ),
        ],
      ),
    );
  }
}

/// A suggestion row in the list view: title + `#number`, two-line excerpt,
/// status / comments / category meta, vote pill on the right.
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
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: colors.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
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
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w800,
                        height: 1.25,
                        color: colors.text,
                      ),
                      children: [
                        TextSpan(
                          text: '  #${post.number}',
                          style: AppText.sans(
                            size: 10.5,
                            weight: FontWeight.w700,
                            color: colors.textDim,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(
                        size: 11,
                        height: 1.45,
                        weight: FontWeight.w500,
                        color: colors.textMed,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(child: StatusBadge(status: post.status)),
                      const SizedBox(width: 11),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 11.5,
                        color: colors.textDim,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${post.commentCount}',
                        style: AppText.sans(
                          size: 10,
                          weight: FontWeight.w700,
                          color: colors.textDim,
                        ),
                      ),
                      const Spacer(),
                      CategoryChip(category: post.category),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            VotePill(votes: post.votes, voted: post.hasVoted, onTap: onVote),
          ],
        ),
      ),
    );
  }
}

/// Compact card used inside the kanban board columns.
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
          borderRadius: BorderRadius.circular(AppRadius.cellSmall),
          boxShadow: colors.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(
                size: 11.5,
                weight: FontWeight.w700,
                height: 1.3,
                color: colors.text,
              ),
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
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 10.5,
                    color: colors.textDim,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${post.commentCount}',
                    style: AppText.sans(
                      size: 9.5,
                      weight: FontWeight.w700,
                      color: colors.textDim,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  '#${post.number}',
                  style: AppText.sans(
                    size: 9.5,
                    weight: FontWeight.w700,
                    color: colors.textDim,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
