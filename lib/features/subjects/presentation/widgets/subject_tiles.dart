import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/subject.dart';
import '../../../../shared/widgets/ic.dart';

/// Target-grade chip (prototype `GradeChip`).
class GradeChip extends StatelessWidget {
  const GradeChip({super.key, required this.grade, required this.color});
  final String grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.alpha8(0x1C), borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ic('goal', size: 14, color: color),
          const SizedBox(width: 3),
          Text(grade, style: AppText.sans(size: 13, weight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// List-mode subject tile (prototype `SubjectRow`).
class SubjectRow extends StatelessWidget {
  const SubjectRow({super.key, required this.subject, this.onTap});
  final Subject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = hexColor(subject.color);
    final meta = AppText.sans(size: 13, color: colors.textDim);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: colors.cardShadow,
        ),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 11),
              Expanded(
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
                                  subject.code ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.sans(size: 12, weight: FontWeight.w800, color: color),
                                ),
                              ),
                              if (subject.credits != null) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '· ${subject.credits} cr',
                                  style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.textDim),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (subject.targetGrade != null) ...[
                          const SizedBox(width: 6),
                          GradeChip(grade: subject.targetGrade!, color: color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subject.name, style: AppText.sans(size: 17, weight: FontWeight.w800, height: 1.2, color: colors.text)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (subject.professor != null) ...[
                          Ic('profile', size: 15, color: colors.textDim),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(subject.professor!, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
                          ),
                          const SizedBox(width: 9),
                        ],
                        Ic('attach', size: 15, color: colors.textDim),
                        const SizedBox(width: 3),
                        Text('${subject.fileCount}', style: meta),
                        if (subject.nextLabel != null) ...[
                          const SizedBox(width: 9),
                          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              subject.nextLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.sans(size: 13, color: color),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid-mode subject tile (prototype `SubjectTile`). Sizes to its content;
/// the grid lays tiles out in rows of two and stretches each pair to the
/// taller one, so a long name or a large text setting grows the tile rather
/// than clipping it.
class SubjectTile extends StatelessWidget {
  const SubjectTile({super.key, required this.subject, this.onTap});
  final Subject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = hexColor(subject.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: colors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: color,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.code ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 12, weight: FontWeight.w800, letterSpacing: AppText.em(0.04, 12), color: Colors.white),
                    ),
                  ),
                  if (subject.targetGrade != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(6)),
                      child: Text(subject.targetGrade!, style: AppText.sans(size: 12, weight: FontWeight.w800, color: Colors.white)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Two lines held open, so a one-line name does not pull the
                  // tile's meta row up out of line with its neighbour's.
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: MediaQuery.textScalerOf(context).scale(41)),
                    child: Text(
                      subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 17, weight: FontWeight.w800, height: 1.2, color: colors.text),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (subject.professor != null) ...[
                    Text(
                      subject.professor!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 12, color: colors.textDim),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      Ic('attach', size: 14, color: colors.textMed),
                      const SizedBox(width: 2),
                      Text('${subject.fileCount}', style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.textMed)),
                      if (subject.credits != null) ...[
                        const SizedBox(width: 8),
                        Text('${subject.credits} cr', style: AppText.sans(size: 12, weight: FontWeight.w700, color: colors.textMed)),
                      ],
                    ],
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

/// Subjects in rows of two (`SUBJ_LAYOUT === 'Grid'`), 9 apart. Each pair is
/// as tall as its taller tile — a fixed aspect ratio clipped the v11 17pt names
/// on a narrow phone.
class SubjectGrid extends StatelessWidget {
  const SubjectGrid({super.key, required this.subjects, required this.onOpen});

  final List<Subject> subjects;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < subjects.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 9),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SubjectTile(subject: subjects[i], onTap: () => onOpen(subjects[i]))),
                const SizedBox(width: 9),
                Expanded(
                  child: i + 1 < subjects.length
                      ? SubjectTile(subject: subjects[i + 1], onTap: () => onOpen(subjects[i + 1]))
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
