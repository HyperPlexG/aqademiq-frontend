import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../services/haptics/haptics_service.dart';
import '../../../../shared/widgets/mood_blob.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/plan_sheet.dart';

/// Result of [showLogMoodSheet]. [note] is null when the optional reflection
/// field was not shown; otherwise it is the trimmed text (may be empty).
typedef LogMoodResult = ({int mood, String? note});

/// "How are you feeling?" check-in, the v11 floating sheet (plan-logmood).
///
/// Presents the 5-step mood scale (idx 0–4) with [initialMood] preselected
/// (default Good / 3). Optionally shows a reflection field when [includeNote]
/// is true (Stats edit flow). Returns the chosen mood on "Log mood", or `null`
/// if the user taps "Skip for now" or dismisses the sheet.
///
/// Reflection is never required — empty note is a valid save, matching Planner.
Future<LogMoodResult?> showLogMoodSheet(
  BuildContext context, {
  int initialMood = 3,
  String? initialNote,
  bool includeNote = false,
}) {
  return showPlanSheet<LogMoodResult>(
    context,
    scrim: const Color(0x42140F1C),
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 38),
    builder: (_) => _LogMoodSheet(
      initialMood: initialMood.clamp(0, 4),
      initialNote: initialNote,
      includeNote: includeNote,
    ),
  );
}

/// Consumer-backed only so the ramp detent can reach `hapticsProvider`; this
/// sheet still owns no app state and still returns its result by popping.
class _LogMoodSheet extends ConsumerStatefulWidget {
  const _LogMoodSheet({
    required this.initialMood,
    required this.initialNote,
    required this.includeNote,
  });

  final int initialMood;
  final String? initialNote;
  final bool includeNote;

  @override
  ConsumerState<_LogMoodSheet> createState() => _LogMoodSheetState();
}

class _LogMoodSheetState extends ConsumerState<_LogMoodSheet> {
  late int _selected = widget.initialMood;
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Tier 3 detent on an actual move, following the melt ramp (§5.1).
  ///
  /// The *commit* haptic is not fired here: this sheet only reports a choice,
  /// and its callers (Plan's menu, Stats' day editor) write the log and fire
  /// `moodLogged` once the write lands.
  void _select(int idx) {
    if (idx != _selected) ref.read(hapticsProvider).moodRampStep(idx);
    setState(() => _selected = idx);
  }

  void _submit() {
    Navigator.of(context).pop((
      mood: _selected,
      note: widget.includeNote ? _note.text.trim() : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          'How are you feeling?',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 28, weight: FontWeight.w800, color: colors.text),
        ),
        const SizedBox(height: 4),
        Text(
          'A quick check-in helps Ada tune your day',
          textAlign: TextAlign.center,
          style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                _MoodColumn(
                  idx: i,
                  selected: _selected == i,
                  onTap: () => _select(i),
                ),
            ],
          ),
        ),
        if (widget.includeNote) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'REFLECTION (OPTIONAL)',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w800,
                letterSpacing: AppText.em(0.12, 12),
                color: colors.textDim,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              cursorColor: colors.text,
              style: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.text),
              decoration: InputDecoration.collapsed(
                hintText: 'What made today that way?',
                hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, color: colors.textDim),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Log mood',
          onPressed: _submit,
        ),
        const SizedBox(height: 4),
        Center(
          child: Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Skip for now',
                  style: AppText.sans(size: 15, color: colors.textMed),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoodColumn extends StatelessWidget {
  const _MoodColumn({
    required this.idx,
    required this.selected,
    required this.onTap,
  });

  final int idx;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final moodColor = MoodScale.colors[idx];

    return Semantics(
      button: true,
      selected: selected,
      label: MoodScale.labels[idx],
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? moodColor.alpha8(0x1E) : null,
                  border: Border.all(
                    color: selected ? moodColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: MoodBlob(idx: idx, size: 34),
              ),
              const SizedBox(height: 7),
              Text(
                MoodScale.labels[idx],
                maxLines: 1,
                softWrap: false,
                style: AppText.sans(
                  size: 12,
                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? moodColor : colors.textMed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
