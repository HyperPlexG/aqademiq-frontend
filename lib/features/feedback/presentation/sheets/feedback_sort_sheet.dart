import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../providers/feedback_providers.dart';

/// Pick how the feedback board is ordered. Returns null on dismiss.
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

  static const List<(FeedbackSort, IconData, String, String)> _options = [
    (
      FeedbackSort.top,
      Icons.trending_up,
      'Most voted',
      'What the community wants most',
    ),
    (FeedbackSort.newest, Icons.schedule, 'Newest', 'Fresh ideas first'),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(sort),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sort == current ? colors.accentSoft : colors.hilite,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color:
                        sort == current ? colors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 21,
                      color: sort == current ? colors.accent : colors.text,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppText.sans(
                              size: 14,
                              weight: FontWeight.w700,
                              color:
                                  sort == current ? colors.accent : colors.text,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: AppText.sans(
                              size: 11.5,
                              color: colors.textMed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sort == current)
                      Icon(Icons.check_circle, size: 22, color: colors.accent),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
