import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/mood_blob.dart';
import '../../../../shared/widgets/primary_button.dart';

/// MOODS palette (index 0→4): Rough, Tired, OK, Good, Great. These match the
/// `border` tone of each cube tone in the prototype.
const List<Color> _moodColors = [
  Color(0xFFA79FC4),
  Color(0xFF9286D2),
  Color(0xFF7D70D9),
  Color(0xFF6A5CE4),
  Color(0xFF5A44F1),
];

/// Result of [showLogMoodSheet]. [note] is null when the optional reflection
/// field was not shown; otherwise it is the trimmed text (may be empty).
typedef LogMoodResult = ({int mood, String? note});

/// "How are you feeling?" check-in bottom sheet (plan-logmood).
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
  return showModalBottomSheet<LogMoodResult>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x42140F1C),
    isScrollControlled: true,
    builder: (context) => _LogMoodSheet(
      initialMood: initialMood.clamp(0, 4),
      initialNote: initialNote,
      includeNote: includeNote,
    ),
  );
}

class _LogMoodSheet extends StatefulWidget {
  const _LogMoodSheet({
    required this.initialMood,
    required this.initialNote,
    required this.includeNote,
  });

  final int initialMood;
  final String? initialNote;
  final bool includeNote;

  @override
  State<_LogMoodSheet> createState() => _LogMoodSheetState();
}

class _LogMoodSheetState extends State<_LogMoodSheet> {
  late int _selected = widget.initialMood;
  late final TextEditingController _note = TextEditingController(
    text: widget.initialNote ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheetTop),
          ),
          boxShadow: colors.sheetShadow,
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0DDD7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'How are you feeling?',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 21, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'A quick check-in helps Ada tune your day',
                  textAlign: TextAlign.center,
                  style: AppText.sans(size: 11.5, color: colors.textMed),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 5; i++)
                      _MoodColumn(
                        idx: i,
                        selected: _selected == i,
                        onTap: () => setState(() => _selected = i),
                      ),
                  ],
                ),
                if (widget.includeNote) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reflection (optional)',
                      style: AppText.sans(
                        size: 10,
                        weight: FontWeight.w800,
                        letterSpacing: AppText.em(0.06, 10),
                        color: colors.textDim,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: colors.bg,
                      borderRadius: BorderRadius.circular(AppRadius.rowInput),
                    ),
                    child: TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      cursorColor: colors.text,
                      style: AppText.sans(size: 12.5, color: colors.text),
                      decoration: InputDecoration.collapsed(
                        hintText: 'What made today that way?',
                        hintStyle: AppText.sans(size: 12.5, color: colors.textDim),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Log mood',
                  onPressed: _submit,
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Skip for now',
                    style: AppText.sans(size: 11.5, color: colors.textMed),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    final moodColor = _moodColors[idx];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
            child: MoodBlob(idx: idx, size: selected ? 34 : 32),
          ),
          const SizedBox(height: 6),
          Text(
            MoodScale.labels[idx],
            style: AppText.sans(
              size: 8.5,
              weight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? moodColor : colors.textMed,
            ),
          ),
        ],
      ),
    );
  }
}
