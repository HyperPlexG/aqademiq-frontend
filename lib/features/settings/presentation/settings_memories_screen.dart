import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/ada_memory.dart';
import '../../../data/repositories/ada_memory_repository.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/settings_row.dart';
import 'widgets/settings_scaffold.dart';

/// settings-memories — what Ada remembers about you, and how to remove it.
///
/// Ada can already recall and forget these on its own, but that is not enough:
/// things held about a person should be inspectable and removable by them
/// directly, not only by asking the assistant that wrote them. That matters most
/// for the memories Ada *inferred*, which the user never explicitly agreed to,
/// so every row says which kind it is.
class SettingsMemoriesScreen extends ConsumerWidget {
  const SettingsMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(adaMemoriesProvider);

    return SettingsScaffold(
      title: 'What Ada remembers',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 20),
          child: Text(
            'Ada keeps a few things in mind between conversations so you '
            "don't have to repeat yourself. Some you've told it; some it "
            "worked out from how you study. Remove anything you'd rather it "
            'forgot.',
            style: AppText.sans(size: 13, height: 1.55, color: colors.text),
          ),
        ),
        ...async.when(
          loading: () => [
            const SizedBox(height: 40),
            Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5)),
          ],
          error: (_, _) => [
            const SizedBox(height: 40),
            Center(
              child: Text(
                "Couldn't load what Ada remembers",
                style: AppText.sans(size: 13, color: colors.textMed),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => unawaited(ref.read(adaMemoriesProvider.notifier).refresh()),
                child: Text('Try again', style: AppText.sans(size: 13, color: colors.accent)),
              ),
            ),
          ],
          data: (memories) => _content(context, ref, memories),
        ),
      ],
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, List<AdaMemory> memories) {
    final colors = context.colors;
    if (memories.isEmpty) return [_EmptyState()];

    final widgets = <Widget>[];
    // Ordered by the enum rather than by what came back, so the sections keep a
    // stable position as memories are added and removed.
    for (final kind in AdaMemoryKind.values) {
      final group = memories.where((m) => m.kind == kind).toList(growable: false);
      if (group.isEmpty) continue;
      widgets
        ..add(GroupLabel(kind.heading))
        ..add(
          SetGroup(
            children: [
              for (var i = 0; i < group.length; i++)
                _MemoryTile(
                  memory: group[i],
                  last: i == group.length - 1,
                ),
            ],
          ),
        )
        ..add(const SizedBox(height: 22));
    }

    widgets.add(
      Center(
        child: TextButton(
          onPressed: () => unawaited(_confirmClear(context, ref, memories.length)),
          child: Text(
            'Forget everything',
            style: AppText.sans(size: 13, color: colors.danger),
          ),
        ),
      ),
    );
    return widgets;
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref, int count) async {
    final colors = context.colors;
    final ok = await showAppDialog<bool>(
      context,
      title: 'Forget everything?',
      // Says what actually happens rather than only warning: Ada keeps working,
      // it just starts from nothing again. A confirm that only threatens makes
      // people hesitate over something they are entitled to do.
      subtitle: 'Ada will forget all $count thing${count == 1 ? '' : 's'} it knows about '
          "how you work. It'll still help you plan — it just won't remember any "
          'of this next time.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DialogConfirmButton(
            label: 'Forget everything',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep them', style: AppText.sans(size: 13, color: colors.textMed)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final removed = await ref.read(adaMemoriesProvider.notifier).clear();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed == null
              ? "Couldn't forget those — try again"
              : 'Ada forgot $removed thing${removed == 1 ? '' : 's'}',
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          // Ada herself, not a generic brain icon — this screen is about her.
          const AdaMascot(size: 56, expr: AdaExpr.neutral),
          const SizedBox(height: 12),
          Text(
            "Ada hasn't picked anything up yet",
            style: AppText.sans(size: 14, weight: FontWeight.w700, color: colors.text),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'As you plan together, Ada will start remembering things like when '
              'you focus best and what you have on each week.',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 12.5, height: 1.5, color: colors.textMed),
            ),
          ),
        ],
      ),
    );
  }
}

/// One memory, with where it came from and a way to remove it.
class _MemoryTile extends ConsumerStatefulWidget {
  const _MemoryTile({required this.memory, required this.last});

  final AdaMemory memory;
  final bool last;

  @override
  ConsumerState<_MemoryTile> createState() => _MemoryTileState();
}

class _MemoryTileState extends ConsumerState<_MemoryTile> {
  bool _removing = false;

  Future<void> _forget() async {
    if (_removing) return;
    setState(() => _removing = true);
    final ok = await ref.read(adaMemoriesProvider.notifier).forget(widget.memory.id);
    if (!mounted) return;
    setState(() => _removing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't forget that — try again")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = widget.memory;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.content,
                  style: AppText.sans(size: 13.5, height: 1.45, color: colors.text),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    // An inference is flagged visually, not just worded
                    // differently: it is the one a user is most likely to
                    // disagree with, and it should be the easiest to spot.
                    if (m.source.isInferred)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.hilite,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          m.source.label,
                          style: AppText.sans(size: 10.5, color: colors.textMed),
                        ),
                      )
                    else
                      Text(
                        m.source.label,
                        style: AppText.sans(size: 10.5, color: colors.textDim),
                      ),
                    if (m.expiresAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'until ${_ymd(m.expiresAt!)}',
                        style: AppText.sans(size: 10.5, color: colors.textDim),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: _removing
                ? Center(
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.textDim),
                    ),
                  )
                : IconButton(
                    onPressed: _forget,
                    icon: Icon(Icons.close, size: 17, color: colors.textDim),
                    tooltip: 'Forget this',
                    splashRadius: 18,
                  ),
          ),
        ],
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
