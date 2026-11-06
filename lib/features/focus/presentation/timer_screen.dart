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
import '../../../shared/icons/app_icon.dart';
import '../../../shared/mascot/ice_timer.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ic.dart';
import '../../freeze/presentation/sheets/choose_apps_sheet.dart';
import '../../freeze/providers/freeze_controller.dart';
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
    final freeze = ref.watch(freezeControllerProvider);
    // The ice chip (fc-ice): only once App freeze is set up, and then a bare
    // outline when nothing is on ice — no badge, no nag, forever.
    final iceCount = freeze.setUp ? freeze.recentApps.count : null;
    final prismMode = session.prismMode ?? defaultPrismMode;

    ref.listen(focusControllerProvider, (prev, next) {
      if (prev?.status != FocusStatus.completed && next.status == FocusStatus.completed) {
        // A linked task is marked done when its session runs to its end
        // (FOC-3). One ended early is not: the end screen asks whether the
        // task got finished instead (FOC-4).
        //
        // This goes straight to the repository, NOT through
        // `DayTasksController.toggleDone` — and it must stay that way. The
        // task-completed haptic lives in that controller, and routing this
        // through it would fire two haptics for one user action: the session's
        // own completion, and a task completion the user did not ask for.
        // Spec §4.3 names this exact case as its sharpest.
        final t = ref.read(linkedTaskProvider);
        if (t != null && !t.done && !next.endedEarly) {
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
              onAppFreeze: _appFreeze,
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
              onAppFreeze: _appFreeze,
              iceCount: iceCount,
              iceKeepOnly: freeze.recentApps.keepOnly,
              onIce: _ice,
              onStart: () => unawaited(_start()),
            ),
    );
  }

  Future<void> _link() async {
    final result = await showLinkTaskSheet(context);
    if (result == null) return;
    final task = result.task;
    ref.read(linkedTaskProvider.notifier).set(task);
    // Adopt the task's own duration so a 5-minute task starts a 5-minute
    // session instead of the default 25. A task without a duration leaves the
    // current session length untouched (configure ignores a null).
    ref.read(focusControllerProvider.notifier).configure(
          taskId: task?.id,
          durationMin: task?.durationMin,
        );
  }

  Future<void> _start() async {
    await ref.read(focusControllerProvider.notifier).start();
    final endsAt = ref.read(focusControllerProvider).endsAt;
    if (endsAt != null) ref.read(freezeControllerProvider.notifier).freezeForFocus(endsAt);
  }

  /// The App freeze pill: the intro on first tap, the hub after.
  void _appFreeze() {
    final setUp = ref.read(freezeControllerProvider).setUp;
    unawaited(context.push(setUp ? Routes.freeze : Routes.freezeIntro));
  }

  /// The ice chip: what goes on ice when this session starts.
  Future<void> _ice() async {
    final current = ref.read(freezeControllerProvider).recentApps;
    final picked = await chooseApps(context, current: current, owner: 'usual', title: 'The usual');
    if (!mounted || picked == null) return;
    ref.read(freezeControllerProvider.notifier).setRecentApps(picked);
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
    required this.onAppFreeze,
    required this.iceCount,
    required this.iceKeepOnly,
    required this.onIce,
    required this.onStart,
  });

  final String durationLabel;
  final String taskTitle;
  final String taskSubject;
  final VoidCallback onLink;
  final VoidCallback onSetTime;
  final VoidCallback onPrism;
  final VoidCallback onAppFreeze;

  /// Null hides the ice chip (App freeze not set up yet).
  final int? iceCount;
  final bool iceKeepOnly;
  final VoidCallback onIce;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _FocusFrame(
      pills: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: FocusPill(iconName: 'prism', label: 'Prism', onTap: onPrism)),
          const SizedBox(width: 8),
          Flexible(child: FocusPill(iconName: 'ac_unit', label: 'App freeze', onTap: onAppFreeze)),
        ],
      ),
      children: [
        Text('Focus', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2, color: colors.text)),
        const SizedBox(height: 10),
        _TaskChip(title: taskTitle, subject: taskSubject, onTap: onLink),
        if (iceCount != null) ...[
          const SizedBox(height: 8),
          _IceChip(count: iceCount!, keepOnly: iceKeepOnly, onTap: onIce),
        ],
        const SizedBox(height: 14),
        const IceTimer(),
        const SizedBox(height: 20),
        // The time IS the control: tap 25:00 and the duration picker opens.
        // Digits stay centred under the cube; the chevron is balanced by a spacer.
        Semantics(
          button: true,
          label: 'Session length $durationLabel',
          child: GestureDetector(
            onTap: onSetTime,
            // Scales down rather than overflowing at large text sizes and on
            // narrow phones (focus_layout_test).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 30),
                  Text(durationLabel, style: AppText.sans(size: 46, weight: FontWeight.w800, letterSpacing: 0.5, height: 1.2, color: colors.text)),
                  Padding(padding: const EdgeInsets.only(top: 4), child: Ic('expand_more', size: 26, color: colors.textDim)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 21),
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
    required this.onAppFreeze,
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
  final VoidCallback onAppFreeze;
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
          Flexible(child: FocusPill(iconName: 'prism', label: prismMode, onTap: onPrism)),
          const SizedBox(width: 8),
          Flexible(child: FocusPill(iconName: 'ac_unit', label: 'App freeze', onTap: onAppFreeze)),
        ],
      ),
      children: [
        Text(paused ? 'Frozen' : 'Focus', style: AppText.sans(size: 34, weight: FontWeight.w800, height: 1.2, color: colors.text)),
        const SizedBox(height: 7),
        Text('$taskSubject · $taskTitle', style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.4, color: colors.textMed)),
        const SizedBox(height: 12),
        IceTimer(progress: progress, frost: paused),
        const SizedBox(height: 20),
        Text(remaining, style: AppText.sans(size: 46, weight: FontWeight.w800, letterSpacing: 0.5, height: 1.2, color: paused ? colors.textMed : colors.text)),
        const SizedBox(height: 20),
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
                style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim),
              ),
            ),
            AppIcon(Icons.expand_more, size: 20, color: colors.textDim),
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
        height: 50,
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        decoration: BoxDecoration(color: colors.ink, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 21, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 17, weight: FontWeight.w800, color: Colors.white),
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
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(Icons.stop_circle, size: 21, color: colors.danger),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'End',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ice chip (fc-ice) — mirrors the task chip exactly, one row lower. Set:
/// "The usual · 9 on ice", frozen for exactly the session it starts. Empty: a
/// bare dashed outline, "Nothing on ice".
class _IceChip extends StatelessWidget {
  const _IceChip({required this.count, required this.keepOnly, required this.onTap});

  final int count;
  final bool keepOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = count == 0 && !keepOnly;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: empty
            ? CustomPaint(
                painter: _DashedPill(color: colors.textDim),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Ic('freeze', size: 18, color: colors.textMed),
                      const SizedBox(width: 6),
                      Text('Nothing on ice', style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.textMed)),
                    ],
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: colors.cardShadow,
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Ic('freeze', size: 18, color: Color(0xFF6B5CF0)),
                    const SizedBox(width: 7),
                    Text('The usual', style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text)),
                    const SizedBox(width: 7),
                    Text(
                      keepOnly ? (count == 0 ? 'everything' : 'all but $count') : '$count on ice',
                      style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textDim),
                    ),
                    AppIcon(Icons.expand_more, size: 20, color: colors.textDim),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DashedPill extends CustomPainter {
  const _DashedPill({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2)).deflate(0.75);
    for (final m in (Path()..addRRect(r)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4 > m.length ? m.length : d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPill old) => old.color != color;
}
