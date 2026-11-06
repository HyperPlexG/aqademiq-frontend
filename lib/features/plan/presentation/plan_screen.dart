import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/hex_color.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/tag.dart';
import '../../../data/models/tag_resolve.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/focus_repository.dart';
import '../../../data/repositories/mood_repository.dart';
import '../../../data/repositories/tags_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../services/haptics/haptics_service.dart';
import '../../../shared/icons/app_icon.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/guest_nudge_card.dart';
import '../../../shared/widgets/ic.dart';
import '../../focus/providers/linked_task_provider.dart';
import '../plan_time.dart';
import '../providers/plan_providers.dart';
import '../providers/plan_ui_providers.dart';
import 'pickers/date_picker.dart';
import 'sheets/log_mood_sheet.dart';
import 'sheets/month_picker_sheet.dart';
import 'sheets/plan_menu.dart';
import 'sheets/quick_add_sheet.dart';
import 'sheets/reschedule_sheet.dart';
import 'sheets/task_overflow_sheet.dart';
import 'widgets/collapse_head.dart';
import 'widgets/plan_date_strip.dart';
import 'widgets/plan_header.dart';
import 'widgets/plan_list_bits.dart';
import 'widgets/plan_task_card.dart';
import 'widgets/plan_task_expanded_card.dart';

/// PLAN_TIMELINE and its state variants (FRAMES `plan-timeline`, `plan-list`,
/// `plan-breakdown`, `plan-anytime/planned-collapsed`, `plan-otherday`).
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _anytimeOpen = true;
  bool _plannedOpen = true;
  /// A breakdown is a model call. Guards against a second tap spending it twice.
  bool _breakingDown = false;

  Future<void> _add() async {
    final result = await showQuickAddSheet(context);
    if (result == null || !mounted) return;
    if (result.details) {
      ref.read(taskDraftProvider.notifier).set(result.draft);
      unawaited(context.push(Routes.addTask));
    } else {
      await _createFromDraft(result.draft);
    }
  }

  Future<void> _createFromDraft(TaskDraft draft) async {
    if (draft.title.isEmpty) return;
    final date = ref.read(selectedDateProvider);
    final tags = ref.read(tagsProvider).value ?? const <Tag>[];
    final repeat = (draft.repeat != null && draft.repeat!.frequency != RepeatFrequency.none)
        ? draft.repeat
        : null;
    // Prefer the raw picker label so "2:30 PM" becomes a real startTime (Planned).
    // Falling back to dayPart alone keeps Morning/Afternoon/Evening + Anytime.
    final resolved = draft.timeLabel != null
        ? PlanTime.resolve(draft.timeLabel!, date)
        : (
            dayPart: draft.dayPart ?? DayPart.anytime,
            startTime: null,
          );
    // The tag picked with Quick-add's Tag chip; without one, the first tag, as
    // before the chip existed.
    final picked = draft.tagId;
    final task = Task(
      id: '',
      title: draft.title,
      tagId: (picked != null && picked.isNotEmpty) ? picked : (tags.isNotEmpty ? tags.first.id : ''),
      date: date,
      dayPart: resolved.dayPart,
      startTime: resolved.startTime,
      durationMin: 30,
      repeat: repeat,
    );
    // Quick add is the OTHER creation path, and until now it was the one that
    // failed in silence: `add_task_screen._save` has always caught and shown a
    // snackbar, while this awaited the create bare. A throw here escaped into
    // the void — the sheet had already closed, no task appeared, and nothing
    // said why. "I added a task and it just didn't add" is what that looks like
    // from the outside, and it is indistinguishable from the app ignoring the
    // tap. Both paths now report the same way.
    try {
      await ref.read(tasksRepositoryProvider).create(task);
    } on Object {
      if (!mounted) return;
      ref.read(hapticsProvider).saveFailed();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't add task. Try again.")),
      );
      return;
    }
    // Second creation path (quick add) alongside `add_task_screen._save`. Same
    // Tier 2 event, not a new one — the state change is identical, so it costs
    // nothing against Plan's budget of 4.
    if (!mounted) return;
    ref.read(hapticsProvider).taskCreated();
    ref.invalidate(dayTasksProvider);
  }

  /// Open the full Add-task form pre-bucketed to [part] (list-view group "+").
  void _addToBucket(DayPart part) {
    ref.read(taskDraftProvider.notifier).set(TaskDraft(dayPart: part));
    unawaited(context.push(Routes.addTask));
  }

  Future<void> _menu() async {
    // The planner can be parked on any day; mood can only be logged for one
    // that has happened.
    final selected = ref.read(selectedDateProvider);
    final today = AppDate.today();
    final selectedDay = DateTime(selected.year, selected.month, selected.day);
    final result = await showPlanMenu(
      context,
      currentGrouping: ref.read(planViewModeProvider),
      canLogMood: !selectedDay.isAfter(today),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case PlanMenuResult.reschedule:
        await showRescheduleSheet(context);
      case PlanMenuResult.logMood:
        final result = await showLogMoodSheet(context);
        if (result != null && mounted) {
          try {
            await ref.read(moodRepositoryProvider).upsertDay(
                  date: ref.read(selectedDateProvider),
                  mood: result.mood,
                );
          } on Object {
            if (!mounted) return;
            ref.read(hapticsProvider).saveFailed();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't save. Try again.")),
            );
            return;
          }
          if (!mounted) return;
          // On commit, and only after it lands — distinct from the ramp detents
          // that preceded it inside the sheet.
          ref.read(hapticsProvider).moodLogged();
          ref.invalidate(moodWeekProvider);
          ref.invalidate(streakProvider);
        }
      case PlanMenuResult.groupingList:
        ref.read(planViewModeProvider.notifier).set(PlanViewMode.list);
      case PlanMenuResult.groupingTimeline:
        ref.read(planViewModeProvider.notifier).set(PlanViewMode.timeline);
    }
  }

  Future<void> _pickMonth() async {
    final date = await showMonthPicker(context, selected: ref.read(selectedDateProvider));
    if (date != null && mounted) ref.read(selectedDateProvider.notifier).select(date);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedDateProvider);
    final tasksAsync = ref.watch(dayTasksProvider);
    final tagsById = ref.watch(tagsByIdProvider);
    final guest = ref.watch(isGuestProvider);
    final viewMode = ref.watch(planViewModeProvider);
    final expandedId = ref.watch(expandedTaskProvider);
    final dateCtrl = ref.read(selectedDateProvider.notifier);

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PlanHeader(
            date: selected,
            isToday: AppDate.sameDay(selected, AppDate.today()),
            guest: guest,
            onMonthTap: _pickMonth,
            onToday: dateCtrl.goToToday,
            onMenu: _menu,
            onAdd: _add,
          ),
          PlanDateStrip(
            selected: selected,
            today: AppDate.today(),
            onSelect: dateCtrl.select,
          ),
          if (guest) ...[
            // Account first, then set-up — the same path as the Ada and Stats
            // prompts (GST-2/3). Going straight to onboarding set a guest up
            // without ever taking an email, so they stayed a guest.
            GuestNudgeCard(
              body: 'Create an account so Ada can plan your week & track stats.',
              ctaLabel: 'Create free account →',
              onCta: () => unawaited(context.push(Routes.signup)),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: tasksAsync.when(
              loading: () => const _PlanLoading(),
              error: (e, _) => _PlanError(onRetry: () => ref.invalidate(dayTasksProvider)),
              data: (tasks) {
                // List mode owns its empty buckets; don't swallow the switch
                // behind the shared "other day" empty state.
                if (viewMode == PlanViewMode.list) {
                  return _PlanListGrouped(
                    tasks: tasks,
                    tagsById: tagsById,
                    onToggleDone: _toggleDone,
                    onAddBucket: _addToBucket,
                  );
                }
                if (tasks.isEmpty) {
                  // Today's empty planner (v11 ib-empty-plan) and another
                  // day's (plan-otherday) differ only in what fills the middle;
                  // both keep the add rows and the Ice Breakers door.
                  return _EmptyDay(
                    isToday: AppDate.sameDay(selected, AppDate.today()),
                    onAdd: _add,
                  );
                }
                return _PlanTimeline(
                  tasks: tasks,
                  tagsById: tagsById,
                  anytimeOpen: _anytimeOpen,
                  plannedOpen: _plannedOpen,
                  expandedId: expandedId,
                  onToggleAnytime: () => setState(() => _anytimeOpen = !_anytimeOpen),
                  onTogglePlanned: () => setState(() => _plannedOpen = !_plannedOpen),
                  onToggleDone: _toggleDone,
                  onExpand: (t) => ref.read(expandedTaskProvider.notifier).toggle(t.id),
                  onToggleStep: _toggleStep,
                  onLater: _later,
                  onDelete: _delete,
                  onOverflow: _overflow,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleDone(Task t) => ref.read(dayTasksProvider.notifier).toggleDone(t);

  void _toggleStep(Task t, Subtask s) =>
      unawaited(ref.read(dayTasksProvider.notifier).toggleStep(t, s));

  /// Both ways to delete — the swipe action and the overflow menu — come
  /// through here, so neither can remove a task without asking (TSK-5).
  void _delete(Task t) => unawaited(_confirmDelete(t));

  Future<void> _confirmDelete(Task t) async {
    final title = t.title.trim().isEmpty ? 'This task' : '"${t.title.trim()}"';
    final ok = await confirmDestructive(
      context,
      title: 'Delete task?',
      // A repeating task loses only the day it was deleted from; the rest of
      // the series stays, and saying so stops people hesitating over it.
      message: t.repeat != null
          ? '$title will be removed from this day. Its other days stay.'
          : '$title will be removed from your plan.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
    );
    if (!ok || !mounted) return;
    await ref.read(dayTasksProvider.notifier).delete(t);
  }

  // "Later" opens the reschedule picker so the user chooses a day, rather than
  // silently jumping the task to tomorrow.
  void _later(Task t) => unawaited(_reschedule(t));

  /// "Break down" / "Break down more".
  ///
  /// This used to skip the call entirely when the task already had steps and
  /// only toggle the expansion, so "Break down more" appeared to do nothing —
  /// it re-showed the same three. With steps present it now REFINES: the server
  /// hands them to the model and asks it to split each one, and rejects a result
  /// that came back no finer, so a failed refinement leaves them untouched
  /// rather than replacing good steps with a generic three.
  Future<void> _breakDown(Task t) async {
    if (_breakingDown) return;
    final refine = t.subtasks.isNotEmpty;
    setState(() => _breakingDown = true);

    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      // A model call takes seconds; without this the button looks dead.
      ..showSnackBar(SnackBar(
        content: Text(refine ? 'Adding more detail…' : 'Breaking this down…'),
        duration: const Duration(seconds: 30),
      ));

    try {
      await ref
          .read(tasksRepositoryProvider)
          .breakdown(t.id, ref.read(selectedDateProvider), refine: refine);
      ref.invalidate(dayTasksProvider);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      // Expand rather than toggle: after generating steps, collapsing the card
      // would hide the very thing the user just asked for.
      if (ref.read(expandedTaskProvider) != t.id) {
        ref.read(expandedTaskProvider.notifier).toggle(t.id);
      }
    } on Object catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            e is Failure
                ? e.message
                : refine
                    ? "Couldn't add more detail. Your steps are unchanged."
                    : "Couldn't break this down. Try again.",
          ),
        ));
    } finally {
      if (mounted) setState(() => _breakingDown = false);
    }
  }

  void _moveToTomorrow(Task t) {
    // Calendar arithmetic, not 24 hours: across a DST change `add(days: 1)`
    // lands at 23:00 the same day or 01:00 the next.
    final d = ref.read(selectedDateProvider);
    final next = DateTime(d.year, d.month, d.day + 1);
    unawaited(ref.read(dayTasksProvider.notifier).move(t, next));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "${t.title}" to tomorrow')),
    );
  }

  Future<void> _reschedule(Task t) async {
    // Same shared date sheet as Add Task / bulk reschedule "More options".
    final picked = await showTaskDatePicker(
      context,
      initial: ref.read(selectedDateProvider),
    );
    if (picked != null && mounted) {
      await ref.read(dayTasksProvider.notifier).move(t, picked);
    }
  }

  void _startSession(Task t) {
    ref.read(linkedTaskProvider.notifier).set(t);
    ref.read(focusControllerProvider.notifier).configure(durationMin: t.durationMin ?? 25, taskId: t.id);
    unawaited(ref.read(focusControllerProvider.notifier).start());
    context.go(Routes.timer);
  }

  /// "35 min · Ada generated · 3 microtasks" — what the sheet's header says
  /// under the title, from the task itself (it used to be that string, fixed).
  static String _overflowSubtitle(Task t) {
    final steps = t.subtasks.length;
    return [
      if (t.durationMin != null) '${t.durationMin} min',
      if (steps > 0) ...['Ada generated', if (steps == 1) '1 microtask' else '$steps microtasks'],
    ].join(' · ');
  }

  Future<void> _overflow(Task t) async {
    // Spec Finding 04 — the only long-press in the app, and until now it was
    // functionally broken: nothing told the user the gesture had registered.
    // First thing in the handler, before any await, so the tick lands with the
    // press rather than with the sheet.
    ref.read(hapticsProvider).longPressTick();
    final tag = resolveStudyTag(ref.read(tagsByIdProvider).values, t.tagId);
    final color = tag != null ? hexColor(tag.color) : context.colors.accent;
    final action = await showTaskOverflowSheet(
      context,
      title: t.title,
      subjectCode: studyTagLabelFromTags(ref.read(tagsByIdProvider).values, t.tagId),
      subjectColor: color,
      subtitle: _overflowSubtitle(t),
      done: t.done,
      hasSteps: t.subtasks.isNotEmpty,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case TaskOverflowAction.markDone:
        _toggleDone(t);
      case TaskOverflowAction.edit:
        await context.push(Routes.addTask, extra: t);
      case TaskOverflowAction.startSession:
        _startSession(t);
      case TaskOverflowAction.reschedule:
        await _reschedule(t);
      case TaskOverflowAction.moveTomorrow:
        _moveToTomorrow(t);
      case TaskOverflowAction.breakDown:
        await _breakDown(t);
      case TaskOverflowAction.delete:
        _delete(t);
    }
  }
}

class _PlanTimeline extends StatelessWidget {
  const _PlanTimeline({
    required this.tasks,
    required this.tagsById,
    required this.anytimeOpen,
    required this.plannedOpen,
    required this.expandedId,
    required this.onToggleAnytime,
    required this.onTogglePlanned,
    required this.onToggleDone,
    required this.onExpand,
    required this.onToggleStep,
    required this.onLater,
    required this.onDelete,
    required this.onOverflow,
  });

  final List<Task> tasks;
  final Map<String, Tag> tagsById;
  final bool anytimeOpen;
  final bool plannedOpen;
  final String? expandedId;
  final VoidCallback onToggleAnytime;
  final VoidCallback onTogglePlanned;
  final ValueChanged<Task> onToggleDone;
  final ValueChanged<Task> onExpand;
  final void Function(Task task, Subtask step) onToggleStep;
  final ValueChanged<Task> onLater;
  final ValueChanged<Task> onDelete;
  final ValueChanged<Task> onOverflow;

  @override
  Widget build(BuildContext context) {
    final anytime = tasks.where((t) => t.startTime == null).toList();
    final planned = tasks.where((t) => t.startTime != null).toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: anytimeOpen ? 10 : 12),
          child: CollapseHead(
            label: 'ANYTIME',
            count: anytime.length,
            open: anytimeOpen,
            icon: 'schedule',
            onTap: onToggleAnytime,
          ),
        ),
        if (anytimeOpen)
          for (final t in anytime)
            // Anytime tasks expand exactly like planned ones. This branch used
            // to build a plain card unconditionally, so a broken-down anytime
            // task had no way to ever show its steps — the breakdown existed in
            // the database and was simply unreachable in the UI.
            if (expandedId == t.id && t.subtasks.isNotEmpty)
              PlanTaskExpandedCard(
                task: t,
                tag: resolveStudyTag(tagsById.values, t.tagId),
                onCollapse: () => onExpand(t),
                onToggleStep: (s) => onToggleStep(t, s),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SwipeableTask(
                  task: t,
                  onLater: () => onLater(t),
                  onDelete: () => onDelete(t),
                  onOverflow: () => onOverflow(t),
                  child: PlanTaskCard(
                    task: t,
                    tag: resolveStudyTag(tagsById.values, t.tagId),
                    onToggleDone: () => onToggleDone(t),
                    onTap: t.subtasks.isNotEmpty ? () => onExpand(t) : null,
                  ),
                ),
              ),
        // The last anytime card brings its own 8; the head adds 2 under it.
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: CollapseHead(label: 'PLANNED', count: planned.length, open: plannedOpen, onTap: onTogglePlanned),
        ),
        if (plannedOpen)
          for (final t in planned) ...[
            _TimeLabel(AppDate.time12h(t.startTime!)),
            if (expandedId == t.id && t.subtasks.isNotEmpty)
              PlanTaskExpandedCard(
                task: t,
                tag: resolveStudyTag(tagsById.values, t.tagId),
                onCollapse: () => onExpand(t),
                onToggleStep: (s) => onToggleStep(t, s),
              )
            else
              _SwipeableTask(
                task: t,
                onLater: () => onLater(t),
                onDelete: () => onDelete(t),
                onOverflow: () => onOverflow(t),
                child: PlanTaskCard(
                  task: t,
                  tag: resolveStudyTag(tagsById.values, t.tagId),
                  showBar: true,
                  onToggleDone: () => onToggleDone(t),
                  onTap: t.subtasks.isNotEmpty ? () => onExpand(t) : null,
                ),
              ),
          ],
      ],
    );
  }
}

/// Wraps a task row with swipe-to-reveal Later/Delete (FRAMES `task-swipe`) and
/// long-press → action sheet (FRAMES `task-overflow`).
class _SwipeableTask extends StatelessWidget {
  const _SwipeableTask({
    required this.task,
    required this.child,
    required this.onLater,
    required this.onDelete,
    required this.onOverflow,
  });

  final Task task;
  final Widget child;
  final VoidCallback onLater;
  final VoidCallback onDelete;
  final VoidCallback onOverflow;

  @override
  Widget build(BuildContext context) {
    // v11 task-swipe: two 62-wide actions (124 of a ~370 card), the last
    // rounded into the card's corner.
    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.34,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onLater(),
            backgroundColor: context.colors.warn,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            child: const _SwipeActionLabel(icon: 'carry_forward', label: 'Later'),
          ),
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFE85476),
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppRadius.card)),
            child: const _SwipeActionLabel(icon: 'delete', label: 'Delete'),
          ),
        ],
      ),
      child: GestureDetector(onLongPress: onOverflow, child: child),
    );
  }
}

/// A swipe action's glyph over its 11/700 label, white.
class _SwipeActionLabel extends StatelessWidget {
  const _SwipeActionLabel({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ic(icon, size: 20, color: Colors.white),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: AppText.sans(size: 11, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}

/// A planned task's start time over its card (v11 `TimeLabel`, 15/800).
class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 7),
      child: Text(
        text,
        style: AppText.sans(size: 15, weight: FontWeight.w800, color: context.colors.text),
      ),
    );
  }
}

/// plan-list: tasks bucketed by time-of-day (via the shared [taskBucket] seam)
/// with tinted, collapsible group heads and a per-group add (PLAN-3 / PLAN-4).
class _PlanListGrouped extends ConsumerWidget {
  const _PlanListGrouped({
    required this.tasks,
    required this.tagsById,
    required this.onToggleDone,
    required this.onAddBucket,
  });

  final List<Task> tasks;
  final Map<String, Tag> tagsById;
  final ValueChanged<Task> onToggleDone;
  final ValueChanged<DayPart> onAddBucket;

  static const List<DayPart> _order = [DayPart.anytime, DayPart.morning, DayPart.afternoon, DayPart.evening];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final collapsed = ref.watch(collapsedGroupsProvider);
    final meta = <DayPart, (String, String, Color?)>{
      DayPart.anytime: ('schedule', 'ANYTIME', null),
      DayPart.morning: ('wb_twilight', 'MORNING', colors.warn),
      DayPart.afternoon: ('wb_sunny', 'AFTERNOON', colors.accent),
      DayPart.evening: ('nights_stay', 'EVENING', colors.success),
    };
    final groups = {for (final p in _order) p: <Task>[]};
    for (final t in tasks) {
      groups[taskBucket(t)]!.add(t);
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final part in _order)
          if (groups[part]!.isNotEmpty) ...[
            ListGroupHead(
              icon: meta[part]!.$1,
              label: meta[part]!.$2,
              count: groups[part]!.length,
              tint: meta[part]!.$3,
              open: !collapsed.contains(part),
              onTap: () => ref.read(collapsedGroupsProvider.notifier).toggle(part),
              onAdd: () => onAddBucket(part),
            ),
            if (!collapsed.contains(part))
              for (final t in groups[part]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  // The bar and the time span mark a timed task (v11 plan-list);
                  // an untimed one in a bucket reads like an anytime card.
                  child: PlanTaskCard(
                    task: t,
                    tag: resolveStudyTag(tagsById.values, t.tagId),
                    showBar: t.startTime != null,
                    showTime: true,
                    onToggleDone: () => onToggleDone(t),
                  ),
                ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// An empty day. Today (v11 `ib-empty-plan`): the two add lines, Ada with
/// "Nothing planned yet", and the Ice Breakers door. Another day
/// (`plan-otherday`): the add row, then the PLANNED day drawn as one free span
/// from 12:00 AM to 11:59 PM, with the same door underneath.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday, required this.onAdd});

  final bool isToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = isToday
        ? <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: CollapseHead(label: 'ANYTIME', count: 0, open: true, icon: 'schedule'),
            ),
            AddLine(label: 'Add a task for anytime', onTap: onAdd),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: CollapseHead(label: 'PLANNED', count: 0, open: true),
            ),
            AddLine(label: 'Add a planned task', onTap: onAdd),
          ]
        : <Widget>[
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: CollapseHead(label: 'ANYTIME', count: 0, open: true, icon: 'schedule'),
            ),
            AddRow(onTap: onAdd),
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 2),
              child: CollapseHead(label: 'PLANNED', count: 0, open: true),
            ),
            const _TimeLabel('12:00 AM'),
            _FreeDaySpan(onAdd: onAdd),
            const _TimeLabel('11:59 PM'),
          ];

    // The add rows stay exactly where they were: creating a task is the
    // primary action and watching must never replace it. What was missing is
    // somewhere to go for the student who does not yet know what a good task
    // even looks like — for whom "add one" is the whole problem, not the
    // answer. So the door sits underneath, secondary, and never instead.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...top,
              Expanded(
                child: isToday
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Sized explicitly: AdaMascot scales to whatever
                              // she is given, and unconstrained she renders
                              // about five times her intended size.
                              const AdaMascot(size: 50, cheeks: true),
                              const SizedBox(height: 10),
                              Text(
                                'Nothing planned yet',
                                textAlign: TextAlign.center,
                                style: AppText.sans(
                                  size: 20,
                                  weight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: colors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(height: 24),
              ),
              const _ShowMeHowButton(),
            ],
          ),
        ),
      ],
    );
  }
}

/// plan-otherday's planned day with nothing in it: a sun-to-wind-down rail,
/// "23h 59m → No plans" and the well "+".
class _FreeDaySpan extends StatelessWidget {
  const _FreeDaySpan({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = Container(
      width: 5,
      height: 5,
      decoration: const BoxDecoration(color: Color(0xFFD6D3CE), shape: BoxShape.circle),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAdd,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A 6-wide rail as drawn; the 19 glyphs overhang it evenly.
            SizedBox(
              width: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Column(
                  children: [
                    SizedBox(
                      height: 19,
                      child: OverflowBox(maxWidth: 19, child: Ic('light_mode', size: 19, color: colors.warn)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        children: [dot, const SizedBox(height: 5), dot, const SizedBox(height: 5), dot],
                      ),
                    ),
                    SizedBox(
                      height: 19,
                      child: OverflowBox(maxWidth: 19, child: Ic('wind_down', size: 19, color: colors.accent)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '23h 59m → No plans',
                  style: AppText.sans(size: 15, color: colors.textDim),
                ),
              ),
            ),
            Center(child: AddCircle(onTap: onAdd)),
          ],
        ),
      ),
    );
  }
}

/// Opens the Ice Breakers section rather than one video: which one is right
/// depends on how far along the student is, and the section already knows.
class _ShowMeHowButton extends StatelessWidget {
  const _ShowMeHowButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // v11: the ghost PBtn — a full-width 50 slab, but the surface colour and
    // a hairline rather than the ink the primary CTAs use. Adding a task is
    // still the main thing to do here; this is only for the student who does
    // not yet know what to add.
    final radius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: colors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => unawaited(context.push(Routes.iceBreakers)),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Ic('ice_breakers', size: 21, color: colors.accent),
              const SizedBox(width: 7),
              Text(
                'Show me how',
                style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text),
              ),
              const SizedBox(width: 7),
              Ic('chevron_right', size: 19, color: colors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanLoading extends StatelessWidget {
  const _PlanLoading();

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: context.colors.accent, strokeWidth: 2.5));
  }
}

class _PlanError extends StatelessWidget {
  const _PlanError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(Icons.cloud_off_rounded, size: 40, color: colors.textDim),
          const SizedBox(height: 12),
          Text("Couldn't load your day", style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text('Try again', style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.accent)),
          ),
        ],
      ),
    );
  }
}
