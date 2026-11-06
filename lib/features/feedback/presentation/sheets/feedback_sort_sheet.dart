import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/ic.dart';
import '../../providers/feedback_providers.dart';

/// Pick how the feedback board is ordered (v11 `feedback-sort`). Returns null
/// on dismiss.
Future<FeedbackSort?> showFeedbackSortSheet(
  BuildContext context, {
  required FeedbackSort current,
}) {
  return showAppBottomSheet<FeedbackSort>(
    context,
    title: 'Sort suggestions',
    subtitle: 'Choose how the board is ordered',
    child: _SortBody(current: current),
  );
}

class _SortBody extends StatelessWidget {
  const _SortBody({required this.current});

  final FeedbackSort current;

  static const List<(FeedbackSort, String, String, String)> _options = [
    (FeedbackSort.top, 'trending_up', 'Most voted', 'What the community wants most'),
    (FeedbackSort.newest, 'schedule', 'Newest', 'Fresh ideas first'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (sort, icon, title, subtitle) in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              button: true,
              selected: sort == current,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(sort),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  decoration: BoxDecoration(
                    color: sort == current ? colors.accentSoft : colors.hilite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sort == current ? colors.accent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Ic(icon, size: 21, color: sort == current ? colors.accent : colors.text),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppText.sans(
                                size: 17,
                                weight: FontWeight.w700,
                                color: sort == current ? colors.accent : colors.text,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
                            ),
                          ],
                        ),
                      ),
                      if (sort == current) ...[
                        const SizedBox(width: 10),
                        Ic('check_circle:fill', size: 22, color: colors.accent),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
