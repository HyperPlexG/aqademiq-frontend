import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/models/task.dart';
import '../../../../services/voice_input_service.dart';
import '../../../../shared/widgets/voice_feedback.dart';
import '../../plan_time.dart';
import '../../providers/plan_ui_providers.dart';
import '../pickers/repeat_picker.dart';
import '../pickers/time_picker.dart';

/// Outcome of the Quick-add sheet: the [TaskDraft] entered, and whether the
/// user asked to continue to the full Add-task form (`details: true` via "More")
/// or quick-create now (`details: false` via send).
typedef QuickAddResult = ({TaskDraft draft, bool details});

/// Presents the lightweight "Quick add" bar (`plan-quickadd`). Returns the
/// [QuickAddResult] on send/More, or `null` if dismissed. Keyboard-aware.
Future<QuickAddResult?> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<QuickAddResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x47140F1C),
    builder: (_) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  const _QuickAddSheet();

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _controller = TextEditingController();
  late final _dictation = Dictation(_controller);

  /// Held from [initState] so [dispose] can end a dictation without `ref`.
  late final VoiceInputController _voice;

  /// Raw picker label — keep the clock string ("2:30 PM"), do not collapse it
  /// through [DayPartX.fromWire] (that maps unknown values to Anytime).
  String? _timeLabel;
  DayPart? _dayPart;
  RepeatRule? _repeat;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceInputProvider.notifier);
  }

  @override
  void dispose() {
    endDictationAfterTeardown(_voice, this);
    _controller.dispose();
    super.dispose();
  }

  /// Tap to talk, tap again to stop. Words go into the field; the task is only
  /// created when the student taps send or More.
  Future<void> _toggleVoice() async {
    if (ref.read(voiceInputProvider).isActiveFor(this)) {
      await _voice.stop(owner: this);
      return;
    }
    _dictation.begin();
    final problem = await _voice.start(
      owner: this,
      // The first tap may sit behind the OS permission prompt; a screen left in
      // the meantime must not have words written into its disposed field.
      onWords: (words) {
        if (mounted) _dictation.show(words);
      },
    );
    if (problem != null && mounted) showVoiceUnavailable(context, problem);
  }

  void _submit({required bool details}) {
    // The mic closes now rather than when the sheet finishes animating away.
    unawaited(_voice.cancel(owner: this));
    Navigator.of(context).pop((
      draft: TaskDraft(
        title: _controller.text.trim(),
        dayPart: _dayPart,
        timeLabel: _timeLabel,
        repeat: _repeat,
      ),
      details: details,
    ));
  }

  Future<void> _pickTime() async {
    final v = await showTimeOfDayPicker(context);
    if (v == null) return;
    // Anchor to an arbitrary date — only the clock / day-part matters here; the
    // real calendar day is applied in create / Add-task.
    final resolved = PlanTime.resolve(v, DateTime(2000));
    setState(() {
      _timeLabel = v;
      _dayPart = resolved.dayPart;
    });
  }

  Future<void> _pickRepeat() async {
    final v = await showRepeatPicker(context);
    if (v != null) setState(() => _repeat = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final voice = ref.watch(voiceInputProvider);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheetTop)),
          boxShadow: colors.sheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0DDD7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _InputPill(
                controller: _controller,
                colors: colors,
                listening: voice.isListeningFor(this),
                starting: voice.isActiveFor(this) && !voice.listening,
                voiceAvailable: voice.unavailable != VoiceUnavailable.unsupported,
                onSpeak: () => unawaited(_toggleVoice()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ContextChip(
                            icon: Icons.schedule,
                            label: _timeLabel ?? 'Anytime',
                            colors: colors,
                            onTap: _pickTime,
                          ),
                          const SizedBox(width: 6),
                          _ContextChip(icon: Icons.repeat, label: repeatRuleLabel(_repeat), colors: colors, onTap: _pickRepeat),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MorePill(colors: colors, onTap: () => _submit(details: true)),
                  const SizedBox(width: 8),
                  _SendButton(colors: colors, onTap: () => _submit(details: false)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Just one thing to do…" input pill with a trailing mic icon.
class _InputPill extends StatelessWidget {
  const _InputPill({
    required this.controller,
    required this.colors,
    required this.listening,
    required this.starting,
    required this.voiceAvailable,
    required this.onSpeak,
  });

  final TextEditingController controller;
  final AppColors colors;

  /// The microphone is open for this sheet.
  final bool listening;

  /// Asked to start, but not capturing yet.
  final bool starting;

  /// False only on a phone with no speech recognizer.
  final bool voiceAvailable;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.rowInput),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              cursorColor: colors.accent,
              style: AppText.sans(size: 14, color: colors.text),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Just one thing to do…',
                hintStyle: AppText.sans(size: 14, color: colors.textDim),
              ),
            ),
          ),
          if (voiceAvailable) ...[
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: listening || starting
                  ? 'Stop voice input'
                  : 'Add a task by voice',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSpeak,
                child: Icon(
                  listening ? Icons.mic : Icons.mic_none,
                  size: 19,
                  color: listening
                      ? colors.accent
                      : starting
                      ? colors.accent.withValues(alpha: 0.45)
                      : colors.textDim,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small `bg`-filled pill carrying a leading icon and a label (e.g. "Anytime").
class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.label,
    required this.colors,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: colors.textMed),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppText.sans(size: 10.5, weight: FontWeight.w700, color: colors.textMed),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "More" affordance — opens the full Add-task form.
class _MorePill extends StatelessWidget {
  const _MorePill({required this.colors, required this.onTap});

  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Icon(Icons.more_horiz, size: 15, color: colors.textMed),
      ),
    );
  }
}

/// 38px ink circle send button — quick-creates the task.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.colors, required this.onTap});

  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: colors.ink, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_upward, size: 18, color: Colors.white),
      ),
    );
  }
}
