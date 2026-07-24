import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/tag_resolve.dart';
import '../../../data/repositories/focus_repository.dart';
import '../../../data/repositories/tags_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../shared/mascot/ice_timer.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../plan/providers/plan_providers.dart';
import '../../settings/providers/prism_settings_provider.dart';
import '../providers/linked_task_provider.dart';
import 'sheets/focus_duration_dialog.dart';
import 'sheets/link_task_sheet.dart';
import 'sheets/prism_picker.dart';
import 'widgets/focus_pill.dart';

/// FRAMES `fc-set` / `fc-running` / `fc-paused` — the Focus tab. Renders the
/// setup when idle and the live (or frozen) session when running.
class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  String _clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(focusControllerProvider);
    final ctrl = ref.read(focusControllerProvider.notifier);
    final linked = ref.watch(linkedTaskProvider);
    final tagsById = ref.watch(tagsByIdProvider);
    final taskTitle = linked?.title ?? 'Focus session';
    final tag = linked != null ? resolveStudyTag(tagsById.values, linked.tagId) : null;
    final taskSubject = linked != null
        ? studyTagLabel(tag, linked.tagId)
        : 'No task linked';
    final defaultPrismMode = ref.watch(prismDefaultModeProvider);
    final prismMode = session.prismMode ?? defaultPrismMode;

    ref.listen(focusControllerProvider, (prev, next) {
      if (prev?.status != FocusStatus.completed && next.status == FocusStatus.completed) {
        // A linked task is marked done when its session finishes (FOC-3).
        final t = ref.read(linkedTaskProvider);
        if (t != null && !t.done) {
          unawaited(ref.read(tasksRepositoryProvider).update(t.copyWith(done: true)));
          ref
            ..invalidate(dayTasksProvider)
            ..invalidate(weeklyCompletedProvider);
        }
        unawaited(context.push(Routes.focusEnd));
      }
    });

    final isRunning = session.status == FocusStatus.running || session.status == FocusStatus.paused;
    final paused = session.status == FocusStatus.paused;

    return AppScaffold(
      child: isRunning
          ? _RunningView(
              paused: paused,
              prismMode: prismMode,
              taskTitle: taskTitle,
              taskSubject: taskSubject,
              remaining: _clock(session.durationMin * 60 - session.elapsedSec),
              progress: session.progress,
              onPrism: _prism,
              onFreeze: ctrl.pause,
              onResume: ctrl.resume,
              onEnd: ctrl.complete,
            )
          : _SetupView(
              durationLabel: _clock(session.durationMin * 60),
              taskTitle: taskTitle,
              taskSubject: taskSubject,
              onLink: _link,
              onSetTime: _setTime,
              onPrism: _prism,
              onStart: ctrl.start,
            ),
    );
  }

  Future<void> _link() async {
    final result = await showLinkTaskSheet(context);
    if (result == null) return;
    ref.read(linkedTaskProvider.notifier).set(result.task);
    ref.read(focusControllerProvider.notifier).configure(taskId: result.task?.id);
  }

  Future<void> _setTime() async {
    final mins = await showFocusDurationDialog(context, current: ref.read(focusControllerProvider).durationMin);
    if (mins != null) ref.read(focusControllerProvider.notifier).configure(durationMin: mins);
  }

  Future<void> _prism() async {
    final session = ref.read(focusControllerProvider);
    final current = session.prismMode ?? ref.read(prismDefaultModeProvider);
    final mode = await showPrismPicker(context, current: current);
    // Configuring mid-session crossfades the running soundscape (the prism
    // audio bridge listens for prismMode changes).
    if (mode != null) ref.read(focusControllerProvider.notifier).configure(prismMode: mode);
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.durationLabel,
    required this.taskTitle,
    required this.taskSubject,
    required this.onLink,
    required this.onSetTime,
    required this.onPrism,
    required this.onStart,
  });

  final String durationLabel;
  final String taskTitle;
  final String taskSubject;
  final VoidCallback onLink;
  final VoidCallback onSetTime;
  final VoidCallback onPrism;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _FocusFrame(
      pills: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: FocusPill(glyph: '◈', label: 'Prism', onTap: onPrism)),
          const SizedBox(width: 8),
          Flexible(child: FocusPill(icon: Icons.timer, label: 'Set time', onTap: onSetTime)),
        ],
      ),
      children: [
        Text('Focus', style: AppText.sans(size: 32, weight: FontWeight.w800, color: colors.text)),
        const SizedBox(height: 8),
        _TaskChip(title: taskTitle, subject: taskSubject, onTap: onLink),
        const SizedBox(height: 12),
        const IceTimer(),
        const SizedBox(height: 14),
        Text(durationLabel, style: AppText.sans(size: 36, weight: FontWeight.w800, letterSpacing: 0.5, color: colors.text)),
        const SizedBox(height: 18),
        _PrimaryAction(icon: Icons.play_arrow, label: 'Start focus', onTap: onStart),
      ],
    );
  }
}

/// Focus layout: the pills stay pinned at the top, and the timer cluster centres
/// in everything below.
///
/// Both views used to be plain top-packed Columns, so the cluster bunched under
/// the header and left the rest of the screen empty — the design frame balances
/// it in the middle instead. Falls back to scrolling when the cluster is taller
/// than the frame (small devices, large text scale) rather than overflowing.
class _FocusFrame extends StatelessWidget {
  const _FocusFrame({required this.pills, required this.children});

  final Widget pills;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        pills,
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.paused,
    required this.prismMode,
    required this.taskTitle,
    required this.taskSubject,
    required this.remaining,
    required this.progress,
    required this.onPrism,
    required this.onFreeze,
    required this.onResume,
    required this.onEnd,
  });

  final bool paused;
  final String prismMode;
  final String taskTitle;
  final String taskSubject;
  final String remaining;
  final double progress;
  final VoidCallback onPrism;
  final VoidCallback onFreeze;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _FocusFrame(
      pills: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: FocusPill(glyph: '◈', label: prismMode, onTap: onPrism)),
          const SizedBox(width: 8),
          const Flexible(child: FocusPill(icon: Icons.timer, label: 'Set time')),
        ],
      ),
      children: [
        Text(paused ? 'Frozen' : 'Focus', style: AppText.sans(size: 32, weight: FontWeight.w800, color: colors.text)),
        const SizedBox(height: 3),
        Text('$taskSubject · $taskTitle', style: AppText.sans(size: 10.5, color: colors.textMed)),
        const SizedBox(height: 12),
        IceTimer(progress: progress, frost: paused),
        const SizedBox(height: 14),
        Text(remaining, style: AppText.sans(size: 36, weight: FontWeight.w800, letterSpacing: 0.5, color: paused ? colors.textMed : colors.text)),
        SizedBox(height: paused ? 22 : 18),
        // Wrap, not Row: at large text scales the two buttons no longer fit side
        // by side and used to overflow the screen edge. They stack instead, and
        // each is capped at the frame width — Wrap hands its children unbounded
        // main-axis constraints, so a button would otherwise still outgrow it.
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in [
                if (paused)
                  _PrimaryAction(icon: Icons.play_arrow, label: 'Resume', onTap: onResume, horizontal: 30)
                else
                  _PrimaryAction(icon: Icons.ac_unit, label: 'Freeze', onTap: onFreeze, horizontal: 30),
                _EndButton(onTap: onEnd),
              ])
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: action,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskChip extends StatelessWidget {
  const _TaskChip({required this.title, required this.subject, this.onTap});
  final String title;
  final String subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: colors.cardShadow,
          border: Border.all(color: colors.border),
        ),
        // Flexible + ellipsis: a long task title or subject used to push this
        // Row past the screen edge (a horizontal RenderFlex overflow) because
        // both Texts sized to their natural width.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 11.5, weight: FontWeight.w700, color: colors.text),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 10.5, color: colors.textDim),
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: colors.textDim),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.icon, required this.label, required this.onTap, this.horizontal = 40});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13, horizontal: horizontal),
        decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 14, weight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndButton extends StatelessWidget {
  const _EndButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_circle, size: 17, color: colors.danger),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'End',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 14, weight: FontWeight.w800, color: colors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
