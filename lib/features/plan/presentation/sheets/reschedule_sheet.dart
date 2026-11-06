import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/tag.dart';
import '../../../../data/models/tag_resolve.dart';
import '../../../../data/models/task.dart';
import '../../../../data/repositories/tags_repository.dart';
import '../../../../shared/widgets/calendar_grid.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../providers/plan_providers.dart';
import '../widgets/plan_sheet.dart';

const _weekdaysFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _fmtDate(DateTime d) => '${_weekdaysFull[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]}';

/// The quiet line under a task in the review: its time span when it is
/// planned ("11:30 AM → 12:00 PM"), otherwise its length ("10m").
String _taskMeta(Task t) {
  final start = t.startTime;
  final dur = t.durationMin;
  if (start != null) {
    if (dur == null || dur <= 0) return AppDate.time12h(start);
    return '${AppDate.time12h(start)} → ${AppDate.time12h(start.add(Duration(minutes: dur)))}';
  }
  return dur != null ? '${dur}m' : 'Anytime';
}

Color _tagColor(Iterable<Tag> tags, Task t) => hexColor(resolveStudyTag(tags, t.tagId)?.color ?? '#6b5cf0');

/// Presents the reschedule review (`plan-resched`) — a full-bleed modal listing
/// the day's remaining (incomplete) tasks, each with a tick. Every task starts
/// ticked; unticking one leaves it on this day. The CTAs move only the ticked
/// tasks (PLAN-14 / PLAN-15), count them, and switch off at zero. Returns
/// `null` on dismiss.
Future<void> showRescheduleSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    // Full-bleed: the review's own SafeArea handles the insets, so its surface
    // (not the scrim over the planner) fills the status-bar strip.
    useSafeArea: false,
    barrierColor: const Color(0x47140F1C),
    builder: (_) => const _RescheduleReview(),
  );
}

class _RescheduleReview extends ConsumerStatefulWidget {
  const _RescheduleReview();

  @override
  ConsumerState<_RescheduleReview> createState() => _RescheduleReviewState();
}

class _RescheduleReviewState extends ConsumerState<_RescheduleReview> {
  /// Tasks unticked to stay on this day. Kept as the exceptions, so a task
  /// that appears while the review is open starts ticked like the rest.
  final Set<String> _leftBehind = {};

  /// A move is running; the CTAs stay off so a second tap cannot move twice.
  bool _moving = false;

  void _toggle(Task t) => setState(() {
        if (!_leftBehind.remove(t.id)) _leftBehind.add(t.id);
      });

  Future<void> _move(List<Task> tasks, DateTime to) async {
    if (_moving || tasks.isEmpty) return;
    setState(() => _moving = true);
    try {
      final ctrl = ref.read(dayTasksProvider.notifier);
      for (final t in tasks) {
        await ctrl.move(t, to);
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = ref.watch(selectedDateProvider);
    final tasks = ref.watch(dayTasksProvider).value ?? const <Task>[];
    final remaining = tasks.where((t) => !t.done).toList();
    final ticked = remaining.where((t) => !_leftBehind.contains(t.id)).toList();
    final tagsById = ref.watch(tagsByIdProvider);
    // Calendar arithmetic, not 24 hours, so a DST change can't skip or repeat a day.
    final tomorrow = DateTime(selected.year, selected.month, selected.day + 1);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: remaining.isEmpty ? 0 : 132,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: const Offset(12, 0),
                        child: _Dismiss(onTap: () => Navigator.of(context).pop()),
                      ),
                    ),
                    _DatePill(label: _fmtDate(selected), colors: colors),
                    const SizedBox(height: 8),
                    Text(
                      'Remaining tasks',
                      style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.12, color: colors.text),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      remaining.isEmpty
                          ? "You're all caught up — nothing left to move."
                          : 'These are the remaining tasks. Anything you want to move to another day?',
                      style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.5, color: colors.textMed),
                    ),
                    const SizedBox(height: 14),
                    if (remaining.isNotEmpty) ...[
                      Text(
                        'Move ${ticked.length} to tomorrow?',
                        style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < remaining.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == remaining.length - 1 ? 0 : 8),
                          child: _ReviewRow(
                            task: remaining[i],
                            color: _tagColor(tagsById.values, remaining[i]),
                            colors: colors,
                            ticked: !_leftBehind.contains(remaining[i].id),
                            onToggle: _moving ? null : () => _toggle(remaining[i]),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (remaining.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyFooter(
                  colors: colors,
                  count: ticked.length,
                  enabled: ticked.isNotEmpty && !_moving,
                  onMoveTomorrow: () => unawaited(_move(ticked, tomorrow)),
                  onMoreOptions: () async {
                    final picked = await showMoveDateSheet(
                      context,
                      tasks: ticked,
                      initial: tomorrow,
                      colorFor: (t) => _tagColor(tagsById.values, t),
                    );
                    if (picked == null || !mounted) return;
                    await _move(ticked, picked);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The bare ✕ (BarDismiss): a 20 glyph in a 44 target.
class _Dismiss extends StatelessWidget {
  const _Dismiss({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(child: Ic('close', size: 20, color: context.colors.textMed)),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      decoration: BoxDecoration(color: colors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label, style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent)),
    );
  }
}

/// A task in the review: its tick, then a card with the tag dot, the 17/800
/// title and its 13 meta line. Ticked = the ink circle with a check (moves);
/// unticked = an empty ring and a quieter card (stays). The whole row toggles.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.task,
    required this.color,
    required this.colors,
    required this.ticked,
    this.onToggle,
  });

  final Task task;
  final Color color;
  final AppColors colors;
  final bool ticked;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: ticked,
      label: ticked ? 'Move ${task.title}' : 'Keep ${task.title} on this day',
      excludeSemantics: true,
      onTap: onToggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ticked ? colors.ink : Colors.transparent,
                shape: BoxShape.circle,
                border: ticked ? null : Border.all(color: colors.textDim, width: 2),
              ),
              child: ticked ? const Ic('check', size: 18, color: Colors.white) : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: ticked ? 1 : 0.5,
                child: _MoveTaskCard(task: task, color: color, radius: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card a task sits in on both reschedule screens.
class _MoveTaskCard extends StatelessWidget {
  const _MoveTaskCard({required this.task, required this.color, required this.radius});

  final Task task;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text)),
                Text(_taskMeta(task), style: AppText.sans(size: 13, color: colors.textDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.colors,
    required this.count,
    required this.enabled,
    required this.onMoveTomorrow,
    required this.onMoreOptions,
  });

  final AppColors colors;

  /// The ticked tasks — what both buttons would move.
  final int count;

  /// Off with nothing ticked (and while a move runs).
  final bool enabled;
  final VoidCallback onMoveTomorrow;
  final VoidCallback onMoreOptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: 'Move to tomorrow ($count)', enabled: enabled, onPressed: onMoveTomorrow),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'More options to move ($count)',
            ghost: true,
            enabled: enabled,
            onPressed: onMoreOptions,
          ),
        ],
      ),
    );
  }
}

/// `plan-move` — "Move (N)": the tasks being moved, a month calendar and one
/// CTA naming the day ("Move (6) to Thursday, 4 Jun"). Resolves to the chosen
/// day, or `null` when dismissed. It only picks the date; the caller moves.
Future<DateTime?> showMoveDateSheet(
  BuildContext context, {
  required List<Task> tasks,
  required DateTime initial,
  required Color Function(Task) colorFor,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x47140F1C),
    builder: (_) => _MoveDateSheet(tasks: tasks, initial: initial, colorFor: colorFor),
  );
}

class _MoveDateSheet extends StatefulWidget {
  const _MoveDateSheet({required this.tasks, required this.initial, required this.colorFor});

  final List<Task> tasks;
  final DateTime initial;
  final Color Function(Task) colorFor;

  @override
  State<_MoveDateSheet> createState() => _MoveDateSheetState();
}

class _MoveDateSheetState extends State<_MoveDateSheet> {
  late DateTime _selected = DateTime(widget.initial.year, widget.initial.month, widget.initial.day);
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  void _shiftMonth(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final media = MediaQuery.of(context);
    final n = widget.tasks.length;
    final firstCol = DateTime(_month.year, _month.month).weekday - 1;
    final total = DateTime(_month.year, _month.month + 1, 0).day;
    final accentDay = (_selected.year == _month.year && _selected.month == _month.month) ? _selected.day : null;

    // The route's `useSafeArea` keeps the sheet clear of the status bar. A
    // modal sheet's builder sees MediaQuery with the top padding removed, so
    // the inset this used to read here was always 0.
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, -8))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(color: const Color(0xFFE0DDD7), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlanSheetTitle('Move ($n)', size: 28, bottom: 4),
                  Text(
                    'When do you want to move this to?',
                    style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textMed),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < n; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == n - 1 ? 16 : 7),
                        child: _MoveTaskCard(task: widget.tasks[i], color: widget.colorFor(widget.tasks[i]), radius: 13),
                      ),
                    Row(
                      children: [
                        Text(
                          '${_monthsFull[_month.month - 1]} ${_month.year}',
                          style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
                        ),
                        const SizedBox(width: 4),
                        Ic('chevron_right', size: 19, color: colors.accent),
                        const Spacer(),
                        _Arrow(icon: 'back', label: 'Previous month', color: colors.textDim, onTap: () => _shiftMonth(-1)),
                        const SizedBox(width: 4),
                        _Arrow(icon: 'chevron_right', label: 'Next month', color: colors.text, onTap: () => _shiftMonth(1)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CalendarGrid(
                      firstCol: firstCol,
                      total: total,
                      accentDay: accentDay,
                      onDayTap: (day) => setState(() => _selected = DateTime(_month.year, _month.month, day)),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 14 + media.viewPadding.bottom),
              child: PlanCta(
                label: 'Move ($n) to ${_fmtDate(_selected)}',
                onTap: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.color, required this.onTap});

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(width: 32, height: 32, child: Center(child: Ic(icon, size: 18, color: color))),
      ),
    );
  }
}
