import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/tag.dart';
import '../../../../data/repositories/tags_repository.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../settings/presentation/sheets/add_tag_sheet.dart';
import '../widgets/plan_sheet.dart';

/// plan-quickadd's "Tag" chip opens this: the student's study tags drawn the
/// way the add-task form draws them (the same [TagChip]s from [tagsProvider],
/// the same dashed "+ New").
///
/// Tapping a tag returns its id; "+ New" creates the tag and returns the new
/// id. Dismissing returns null, which leaves the pick as it was. [current] is
/// highlighted; with none, the first tag is, because that is the tag a task
/// saved without a pick gets — the add-task form highlights it for the same
/// reason.
Future<String?> showTagPicker(BuildContext context, {String? current}) {
  return showPlanSheet<String>(
    context,
    builder: (_) => _TagPickerSheet(current: current),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({this.current});

  final String? current;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  /// A create is in flight; a second "+ New" would make a second tag.
  bool _adding = false;

  /// Same path as the add-task form's "+ New": the Settings sheet, then the
  /// shared tags store, then the created tag by its label.
  Future<void> _addTag() async {
    final draft = await showAddTagSheet(context);
    if (draft == null || !mounted) return;
    setState(() => _adding = true);
    try {
      await ref.read(tagsProvider.notifier).add(label: draft.label, colorHex: hexFromColor(draft.color));
    } on Object {
      if (!mounted) return;
      setState(() => _adding = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text("Couldn't add tag. Try again.")),
      );
      return;
    }
    if (!mounted) return;
    final tags = ref.read(tagsProvider).value ?? const <Tag>[];
    Tag? created;
    for (final t in tags) {
      if (t.label == draft.label) created = t;
    }
    setState(() => _adding = false);
    if (created != null) Navigator.of(context).pop(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tagsAsync = ref.watch(tagsProvider);
    final tags = tagsAsync.value ?? const <Tag>[];
    final current = widget.current;
    final effective = (current != null && tags.any((t) => t.id == current))
        ? current
        : (tags.isNotEmpty ? tags.first.id : null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlanSheetTitle('Tag', sub: "What's this for?"),
        if (tags.isEmpty && tagsAsync.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.accent),
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final t in tags)
                TagChip(
                  label: t.label,
                  color: hexColor(t.color),
                  active: effective == t.id,
                  onTap: _adding ? null : () => Navigator.of(context).pop(t.id),
                ),
              TagChip(
                label: '+ New',
                color: colors.accent,
                dashed: true,
                onTap: _adding ? null : () => unawaited(_addTag()),
              ),
            ],
          ),
      ],
    );
  }
}
