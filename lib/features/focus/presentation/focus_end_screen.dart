import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/tag_resolve.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/focus_repository.dart';
import '../../../data/repositories/tags_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../shared/widgets/mood_blob.dart';
import '../../plan/providers/plan_providers.dart';
import '../../settings/providers/prism_settings_provider.dart';
import '../providers/linked_task_provider.dart';

/// FRAMES `fc-end` — session-complete summary + mood capture, on a light
/// gradient. Uses a fixed dark ink (independent of theme) like the prototype.
class FocusEndScreen extends ConsumerStatefulWidget {
  const FocusEndScreen({super.key});

  @override
  ConsumerState<FocusEndScreen> createState() => _FocusEndScreenState();
}

class _FocusEndScreenState extends ConsumerState<FocusEndScreen> {
  static const _ink = Color(0xFF1A1320);
  static const _inkSub = Color.fromRGBO(36, 24, 52, 0.58);
  int _mood = 3;
  bool _submitting = false;

  /// The answer to "Did you finish …?", asked only when a linked session was
  /// ended early. Null until answered, and unanswered counts as not yet: a
  /// task is never ticked off on a guess (FOC-4).
  bool? _finished;

  /// The linked task this screen should ask about, or null when there is no
  /// question: no task, already done, or a session that ran to its end (the
  /// timer screen ticks that one off itself).
  Task? get _askAbout {
    final session = ref.read(focusControllerProvider);
    final linked = ref.read(linkedTaskProvider);
    if (linked == null || linked.done || !session.endedEarly) return null;
    return linked;
  }

  /// Time actually focused, not the planned duration. Ending a 30-minute
  /// session after 20 seconds must read 00:20, not 30:00 — `elapsedSec` is the
  /// real count the controller preserves through `complete()`.
  String get _duration {
    final elapsed = ref.read(focusControllerProvider).elapsedSec;
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Send what this screen collected, then leave.
  ///
  /// The mood picker was previously decorative: the timer's End button calls
  /// complete() with no arguments and this screen only ever reset the
  /// controller, so every mood the user selected was discarded. Both fields are
  /// submitted here instead.
  ///
  /// A second complete() is safe — the server pins ended_at and the duration to
  /// the first one, so the summary sitting on screen cannot stretch the session.
  /// It is also best-effort: failing to record a mood must never trap someone on
  /// this screen.
  Future<void> _submitThen(void Function() go) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(focusControllerProvider.notifier)
          .complete(mood: _mood);
    } on Object {
      // Non-fatal.
    }
    if (!mounted) return;
    _settleLinkedTask();
    ref.read(focusControllerProvider.notifier).reset();
    go();
  }

  /// Writes the answer to "Did you finish …?" back to the task.
  ///
  /// Yes ticks it off. Not yet keeps it open and takes the minutes just spent
  /// off what is left, so the plan reflects the work that did happen. Straight
  /// to the repository, like the timer screen's own auto-complete and for the
  /// same reason: routing through the plan controller would add a second
  /// haptic to one action. Fire-and-forget, so a failed write never holds
  /// anyone on this screen.
  void _settleLinkedTask() {
    final task = _askAbout;
    if (task == null) return;
    final Task next;
    if (_finished ?? false) {
      next = task.copyWith(done: true);
    } else {
      final planned = task.durationMin;
      final spent = ref.read(focusControllerProvider).elapsedSec ~/ 60;
      if (planned == null || spent == 0) return;
      // Never below five minutes — the server's own floor for an estimate.
      // Running past the estimate without finishing means it was off, not
      // that nothing is left.
      next = task.copyWith(durationMin: math.max(planned - spent, 5));
    }
    unawaited(
      ref.read(tasksRepositoryProvider).update(next).then((_) {
        ref
          ..invalidate(dayTasksProvider)
          ..invalidate(weeklyCompletedProvider);
      }).catchError((Object _) {}),
    );
  }

  void _backToPlan() => unawaited(_submitThen(() => context.go(Routes.plan)));

  void _again() => unawaited(_submitThen(context.pop));

  /// What this session actually was.
  ///
  /// Both lines on this screen were literal prototype copy until now —
  /// "Deep Work · Prism" and "LL(1) parsing notes · CC 401" — so every student
  /// finished every session being told they had studied LL(1) parsing for
  /// CC 401. Resolved the same way the timer screen resolves them, so the two
  /// screens can never describe one session differently.
  ({String mode, String what}) _summary() {
    final linked = ref.read(linkedTaskProvider);
    if (linked == null) return (mode: _mode(), what: 'Focus session');
    final tag = resolveStudyTag(ref.read(tagsByIdProvider).values, linked.tagId);
    return (mode: _mode(), what: '${linked.title} · ${studyTagLabel(tag, linked.tagId)}');
  }

  /// The mode the session ran in, falling back to the default exactly as the
  /// timer screen does.
  String _mode() =>
      ref.read(focusControllerProvider).prismMode ?? ref.read(prismDefaultModeProvider);

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    final askAbout = _askAbout;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F2FF), Color(0xFFC9BCF8), Color(0xFF6B5CF0)],
            stops: [0, 0.46, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('◈', style: TextStyle(fontSize: 11, color: Color(0xFF6B5CF0), height: 1)),
                        const SizedBox(width: 6),
                        Text('${summary.mode} · Prism', style: AppText.sans(size: 10, weight: FontWeight.w700, color: _ink)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Session done', style: AppText.sans(size: 26, weight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 5),
                  Text(summary.what, style: AppText.sans(size: 11.5, color: _inkSub)),
                  const SizedBox(height: 18),
                  Text(_duration, style: AppText.sans(size: 48, weight: FontWeight.w800, letterSpacing: 0.5, height: 1, color: _ink)),
                  const SizedBox(height: 6),
                  Text('Focused', style: AppText.sans(size: 12, color: _inkSub)),
                  const SizedBox(height: 18),
                  if (askAbout != null) ...[
                    _FinishedCard(
                      title: askAbout.title,
                      finished: _finished,
                      onAnswer: (v) => setState(() => _finished = v),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _MoodCard(selected: _mood, onSelect: (i) => setState(() => _mood = i)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _backToPlan,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(100)),
                      child: Text('Back to today →', textAlign: TextAlign.center, style: AppText.sans(size: 14, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _again,
                    child: Text('Start another session', style: AppText.sans(size: 11.5, color: _inkSub)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Did you finish …?" — shown when a session linked to a task was ended
/// before its time was up.
class _FinishedCard extends StatelessWidget {
  const _FinishedCard({required this.title, required this.finished, required this.onAnswer});
  final String title;
  final bool? finished;
  final ValueChanged<bool> onAnswer;

  static const _ink = Color(0xFF1A1320);
  static const _accent = Color(0xFF6B5CF0);

  @override
  Widget build(BuildContext context) {
    final name = title.trim().isEmpty ? 'this task' : title.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text(
            'Did you finish $name?',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.sans(size: 12, weight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            finished == true
                ? "It'll be ticked off."
                : 'If not, it stays on your plan with the time you spent taken off.',
            textAlign: TextAlign.center,
            style: AppText.sans(size: 10.5, height: 1.4, color: const Color.fromRGBO(36, 24, 52, 0.58)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _choice('Not yet', selected: finished == false, onTap: () => onAnswer(false))),
              const SizedBox(width: 8),
              Expanded(child: _choice('Yes, done', selected: finished == true, onTap: () => onAnswer(true))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, {required bool selected, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.13) : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? _accent : const Color(0x33241834), width: selected ? 2 : 1),
          ),
          child: Text(label, style: AppText.sans(size: 12, weight: FontWeight.w700, color: _ink)),
        ),
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const _colors = [Color(0xFFA79FC4), Color(0xFF9286D2), Color(0xFF7D70D9), Color(0xFF6A5CE4), Color(0xFF5A44F1)];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text('How was that session?', style: AppText.sans(size: 12, weight: FontWeight.w700, color: const Color(0xFF1A1320))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == selected ? _colors[i].withValues(alpha: 0.13) : Colors.transparent,
                        border: Border.all(color: i == selected ? _colors[i] : Colors.transparent, width: 2),
                      ),
                      child: MoodBlob(idx: i, size: i == selected ? 32 : 29),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}


///
/// Deliberately skippable and unselected by default: a forced rating produces
/// compliance data rather than a signal, and the analytics treat null as "not
/// asked" rather than as a middling score. Tapping the current value clears it.
