import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_toggle.dart';
import '../../../../shared/widgets/ic.dart';
import '../../providers/subjects_ui_providers.dart';

/// Presents the "Sort subjects" sheet (`subj-sort`) — the v11 floating sheet
/// over the dimmed Subjects list. Lists five ordering options plus a "Reverse
/// order" toggle, both reading and writing [subjectSortProvider]: tapping an
/// option applies it and closes the sheet, the toggle applies at once.
Future<void> showSortSubjectsSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: 'Sort subjects',
    subtitle: 'Choose how your subjects are ordered',
    scrim: AppScrim.picker,
    child: const _SortSubjectsBody(),
  );
}

/// One sortable ordering option as shown in the sheet.
class _SortOption {
  const _SortOption({
    required this.sortKey,
    required this.icon,
    required this.label,
    required this.sub,
  });

  final SubjectSortKey sortKey;

  /// A design icon name.
  final String icon;
  final String label;
  final String sub;
}

const _options = <_SortOption>[
  _SortOption(
    sortKey: SubjectSortKey.manual,
    icon: 'drag_indicator',
    label: 'Manual order',
    // The design says "Drag to arrange", but subjects have no stored position
    // and nothing reorders them by hand yet: Manual is the order they arrive.
    sub: 'In the order you added them',
  ),
  _SortOption(
    sortKey: SubjectSortKey.alphabetical,
    icon: 'sort_by_alpha',
    label: 'Alphabetical',
    sub: 'A → Z',
  ),
  _SortOption(
    sortKey: SubjectSortKey.grade,
    icon: 'grade',
    label: 'Grade',
    sub: 'Highest target first',
  ),
  _SortOption(
    sortKey: SubjectSortKey.credits,
    icon: 'workspace_premium',
    label: 'Credits',
    sub: 'Most credits first',
  ),
  _SortOption(
    sortKey: SubjectSortKey.mood,
    icon: 'sentiment_satisfied',
    label: 'Mood',
    sub: 'How you feel about each',
  ),
];

class _SortSubjectsBody extends ConsumerWidget {
  const _SortSubjectsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final sort = ref.watch(subjectSortProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == _options.length - 1 ? 0 : 1,
            ),
            child: _OptRow(
              option: _options[i],
              active: _options[i].sortKey == sort.key,
              onTap: () {
                ref.read(subjectSortProvider.notifier).setKey(_options[i].sortKey);
                Navigator.of(context).pop();
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Reverse order',
                  style: AppText.sans(
                    size: 17,
                    weight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
              ),
              AppToggle(
                value: sort.reverse,
                onChanged: (v) =>
                    ref.read(subjectSortProvider.notifier).setReverse(reverse: v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// OptRow: min 52 high, the active option on the accent tint with a check.
class _OptRow extends StatelessWidget {
  const _OptRow({
    required this.option,
    required this.active,
    required this.onTap,
  });

  final _SortOption option;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.accent;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Ic(
                option.icon,
                size: 19,
                color: active ? accent : colors.textMed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppText.sans(
                        size: 17,
                        weight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? accent : colors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      option.sub,
                      style: AppText.sans(size: 13, color: colors.textDim),
                    ),
                  ],
                ),
              ),
              if (active) ...[
                const SizedBox(width: 12),
                Ic('check', size: 20, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
