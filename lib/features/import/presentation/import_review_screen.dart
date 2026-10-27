import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/hex_color.dart';
import '../../../data/models/import_item.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/tags_repository.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../plan/providers/plan_providers.dart';
import '../../settings/presentation/widgets/settings_scaffold.dart';
import '../providers/import_session.dart';
import 'widgets/import_widgets.dart';

/// The one review step every import source lands on: choose calendars, range
/// and tag, untick what should stay out, then add the rest to the plan.
class ImportReviewScreen extends ConsumerWidget {
  const ImportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final s = ref.watch(importSessionProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  const SettingsBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.title.isEmpty ? 'Import' : s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: _ReviewBody()),
            const _ReviewFooter(),
          ],
        ),
      ),
    );
  }
}

// ---- body --------------------------------------------------------------------

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final s = ref.watch(importSessionProvider);
    final session = ref.read(importSessionProvider.notifier);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final result = s.result;
    final editable = s.phase == ImportPhase.ready || s.phase == ImportPhase.loading;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (s.phase == ImportPhase.done && result != null) ...[
          _DoneCard(result: result),
          const SizedBox(height: 18),
        ],
        if (s.groups.isNotEmpty && s.phase != ImportPhase.done) ...[
          GroupLabel(s.source == ImportSourceKind.deviceReminders ? 'Lists' : 'Calendars'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final g in s.groups)
                ImportChip(
                  label: g.title,
                  selected: s.selectedGroups.contains(g.id),
                  dotColor: g.colorHex == null ? null : hexColor(g.colorHex!),
                  onTap: () => session.toggleGroup(g.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (s.rangeDays != null && s.phase != ImportPhase.done && s.phase != ImportPhase.failed) ...[
          const GroupLabel('How far ahead'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final days in importRangeOptions)
                ImportChip(
                  label: _rangeLabel(days),
                  selected: s.rangeDays == days,
                  onTap: () => session.setRange(days),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (editable) ...[
          const GroupLabel('Add as'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ImportChip(label: 'No tag', selected: s.tagId == null, onTap: () => session.setTag(null)),
              for (final t in tags)
                ImportChip(
                  label: t.label,
                  dotColor: hexColor(t.color),
                  selected: s.tagId == t.id,
                  onTap: () => session.setTag(t.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        ..._items(context, s, session, colors),
      ],
    );
  }

  List<Widget> _items(BuildContext context, ImportSessionState s, ImportSession session, AppColors colors) {
    if (s.phase == ImportPhase.loading) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator(color: colors.accent, strokeWidth: 2.5)),
        ),
      ];
    }
    if (s.phase == ImportPhase.failed) {
      return [
        _Notice(
          icon: Icons.error_outline,
          text: s.message ?? "Couldn't read that.",
          action: session.canRetry ? 'Try again' : null,
          onAction: () => unawaited(session.retry()),
        ),
      ];
    }
    if (s.items.isEmpty) {
      return [
        if (s.hiddenInPlan > 0)
          _Notice(icon: Icons.event_available_outlined, text: 'All ${s.hiddenInPlan} are already in your plan.')
        else
          _Notice(icon: Icons.event_busy_outlined, text: _emptyText(s)),
      ];
    }

    final listedInPlan = s.items.where(s.isInPlan).length;
    final pickable = s.items.length - listedInPlan;
    // Counted with the ones set aside to keep a very long list reviewable.
    final found = s.items.length + s.hiddenInPlan;
    final inPlan = listedInPlan + s.hiddenInPlan;
    final allTicked = pickable > 0 && s.selectedCount == pickable;
    final showGroup = s.groups.length > 1;
    final byDay = <DateTime, List<ImportItem>>{};
    for (final item in s.items) {
      (byDay[item.date] ??= <ImportItem>[]).add(item);
    }

    return [
      Row(
        children: [
          Expanded(
            child: Text(
              inPlan == 0 ? '$found found' : '$found found · $inPlan already in your plan',
              style: AppText.sans(size: 12.5, weight: FontWeight.w700, color: colors.textMed),
            ),
          ),
          if (s.phase == ImportPhase.ready && pickable > 0)
            GestureDetector(
              onTap: allTicked ? session.selectNone : session.selectAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
                child: Text(
                  allTicked ? 'Clear' : 'Select all',
                  style: AppText.sans(size: 12.5, weight: FontWeight.w800, color: colors.accent),
                ),
              ),
            ),
        ],
      ),
      if (s.truncated)
        ImportCaption(
          'Showing the first ${s.items.length}. Add these, then import again for the rest — nothing is added twice.',
          padding: const EdgeInsets.fromLTRB(3, 6, 3, 0),
        ),
      for (final entry in byDay.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(3, 16, 3, 8),
          child: Text(
            _dayLabel(entry.key),
            style: AppText.sans(size: 12.5, weight: FontWeight.w800, color: colors.text),
          ),
        ),
        SetGroup(
          children: [
            for (var i = 0; i < entry.value.length; i++)
              _ItemRow(
                item: entry.value[i],
                checked: s.selected.contains(entry.value[i].externalId),
                inPlan: s.isInPlan(entry.value[i]),
                removed: s.wasRemoved(entry.value[i]),
                showGroup: showGroup,
                enabled: s.phase == ImportPhase.ready,
                last: i == entry.value.length - 1,
                onTap: () => session.toggleItem(entry.value[i]),
              ),
          ],
        ),
      ],
    ];
  }

  static String _emptyText(ImportSessionState s) => switch (s.source) {
        ImportSourceKind.deviceCalendar => s.selectedGroups.isEmpty
            ? 'Pick at least one calendar.'
            : 'No events in this range. Try looking further ahead, or another calendar.',
        ImportSourceKind.deviceReminders =>
          s.selectedGroups.isEmpty ? 'Pick at least one list.' : 'No open reminders in these lists.',
        ImportSourceKind.ics => 'Nothing in this calendar falls in this range. Try looking further ahead.',
        ImportSourceKind.text => 'No reminders found. Put each one on its own line.',
      };
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.checked,
    required this.inPlan,
    required this.removed,
    required this.showGroup,
    required this.enabled,
    required this.last,
    required this.onTap,
  });

  final ImportItem item;
  final bool checked;
  final bool inPlan;
  final bool removed;
  final bool showGroup;
  final bool enabled;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final group = item.groupTitle;
    final when = _whenLabel(item);
    final subtitle = showGroup && group != null && group.isNotEmpty ? '$when · $group' : when;
    final badge = inPlan ? 'In your plan' : (removed ? 'Removed before' : null);
    return InkWell(
      onTap: inPlan || !enabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            ImportCheckCircle(checked: checked, locked: inPlan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 13.5, height: 1.3, color: inPlan ? colors.textMed : colors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.sans(size: 11, color: colors.textMed),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              ImportBadge(badge),
            ],
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = action;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 30, color: colors.textDim),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppText.sans(size: 13, height: 1.5, color: colors.textMed),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            PrimaryButton(label: label, ghost: true, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.result});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final n = result.imported;
    final skipped = result.skipped;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 28, color: colors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 0 ? 'Everything was already in your plan' : 'Added $n ${n == 1 ? 'task' : 'tasks'} to your plan',
                  style: AppText.sans(size: 14.5, weight: FontWeight.w800, color: colors.text),
                ),
                if (skipped > 0 && n > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$skipped ${skipped == 1 ? 'was' : 'were'} already there, so ${skipped == 1 ? 'it was' : 'they were'} left as they are.',
                      style: AppText.sans(size: 11.5, height: 1.4, color: colors.textMed),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- footer ------------------------------------------------------------------

class _ReviewFooter extends ConsumerWidget {
  const _ReviewFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final s = ref.watch(importSessionProvider);
    final session = ref.read(importSessionProvider.notifier);

    final List<Widget> children;
    if (s.phase == ImportPhase.done) {
      children = [
        PrimaryButton(label: 'See it in my plan', onPressed: () => _openPlan(context, ref, s)),
        const SizedBox(height: 8),
        PrimaryButton(label: 'Done', ghost: true, onPressed: () => Navigator.of(context).maybePop()),
      ];
    } else if (s.phase == ImportPhase.failed) {
      children = [
        PrimaryButton(label: 'Back', ghost: true, onPressed: () => Navigator.of(context).maybePop()),
      ];
    } else {
      final n = s.selectedCount;
      final String label;
      if (s.phase == ImportPhase.importing) {
        label = s.total > 100 ? 'Adding ${s.done} of ${s.total}…' : 'Adding…';
      } else if (n == 0) {
        label = 'Pick what to add';
      } else {
        label = 'Add $n to my plan';
      }
      final message = s.phase == ImportPhase.ready ? s.message : null;
      children = [
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 12, height: 1.4, color: colors.danger),
            ),
          ),
        PrimaryButton(
          label: label,
          enabled: s.phase == ImportPhase.ready && n > 0,
          onPressed: () => unawaited(session.runImport()),
        ),
      ];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  /// Open the Plan on the first day this import added something to, so the
  /// new tasks are the first thing the student sees rather than an unchanged
  /// today.
  void _openPlan(BuildContext context, WidgetRef ref, ImportSessionState s) {
    ref.read(selectedDateProvider.notifier).select(s.firstAdded ?? importToday());
    context.go(Routes.plan);
  }
}

// ---- labels ------------------------------------------------------------------

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _rangeLabel(int days) => switch (days) {
      7 => '1 week',
      14 => '2 weeks',
      30 => '1 month',
      90 => '3 months',
      _ => '$days days',
    };

/// "Today", "Tomorrow", or "Wed 28 Oct" (plus the year when it is not this one).
String _dayLabel(DateTime day) {
  final today = importToday();
  if (AppDate.sameDay(day, today)) return 'Today';
  if (AppDate.sameDay(day, DateTime(today.year, today.month, today.day + 1))) return 'Tomorrow';
  final label = '${AppDate.weekdayFull(day).substring(0, 3)} ${day.day} ${_monthsShort[day.month - 1]}';
  return day.year == today.year ? label : '$label ${day.year}';
}

String _whenLabel(ImportItem item) {
  final start = item.startTime;
  if (item.allDay) return 'All day';
  if (start != null) {
    final minutes = item.durationMin;
    final from = AppDate.time12h(start);
    return minutes == null ? from : '$from – ${AppDate.time12h(start.add(Duration(minutes: minutes)))}';
  }
  return switch (item.placement) {
    ImportPlacement.overdue => 'Overdue · goes on today',
    ImportPlacement.undated => 'No date · goes on today',
    ImportPlacement.asScheduled => 'Any time',
  };
}
