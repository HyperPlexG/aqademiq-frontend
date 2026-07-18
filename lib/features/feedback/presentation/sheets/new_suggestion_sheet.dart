import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/launch_external.dart';
import '../../../../data/models/enums.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../widgets/feedback_bits.dart';

/// What the "Make a suggestion" sheet returns to the board screen.
typedef FeedbackDraft = ({
  String title,
  String body,
  FeedbackCategory category,
});

/// The Tiimo-style "Make a suggestion" composer: category picker, title,
/// optional details, and a direct-support nudge when Bug is selected.
/// [initial] prefills the form (used to retry a draft after a failed submit).
Future<FeedbackDraft?> showNewSuggestionSheet(
  BuildContext context, {
  FeedbackDraft? initial,
}) {
  return showAppBottomSheet<FeedbackDraft>(
    context,
    title: 'Make a suggestion',
    subtitle: 'Share an idea — the community votes on what gets built.',
    child: _SuggestionBody(initial: initial),
  );
}

class _SuggestionBody extends StatefulWidget {
  const _SuggestionBody({this.initial});

  final FeedbackDraft? initial;

  @override
  State<_SuggestionBody> createState() => _SuggestionBodyState();
}

class _SuggestionBodyState extends State<_SuggestionBody> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.feature;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _title.text = initial.title;
      _body.text = initial.body;
      _category = initial.category;
    }
    _canSubmit = _title.text.trim().isNotEmpty;
    _title.addListener(() {
      final can = _title.text.trim().isNotEmpty;
      if (can != _canSubmit) setState(() => _canSubmit = can);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop((
      title: _title.text.trim(),
      body: _body.text.trim(),
      category: _category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final category in FeedbackCategory.values) ...[
              if (category != FeedbackCategory.values.first)
                const SizedBox(width: 7),
              Expanded(
                child: _CategoryOption(
                  category: category,
                  selected: category == _category,
                  onTap: () => setState(() => _category = category),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Title'),
        AppTextField(
          controller: _title,
          hint: 'One clear sentence',
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        const FieldLabel('Details (optional)'),
        _MultilineField(
          controller: _body,
          hint: 'What problem does it solve? How should it work?',
        ),
        if (_category == FeedbackCategory.bug) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.danger.alpha8(0x14),
              borderRadius: BorderRadius.circular(AppRadius.rowInput),
            ),
            child: Row(
              children: [
                Icon(Icons.bug_report_outlined, size: 15, color: colors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Blocked by a bug right now? Email the team and we will help directly.',
                    style: AppText.sans(
                      size: 10.5,
                      height: 1.4,
                      color: colors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(
                    openExternal(
                      context,
                      Uri.parse('mailto:hello@aqademiq.app?subject=Bug report'),
                    ),
                  ),
                  child: Text(
                    'Email →',
                    style: AppText.sans(
                      size: 11,
                      weight: FontWeight.w800,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _canSubmit ? _submit : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _canSubmit ? colors.ink : colors.hilite,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Share suggestion',
              textAlign: TextAlign.center,
              style: AppText.sans(
                size: 13.5,
                weight: FontWeight.w800,
                color: _canSubmit ? Colors.white : const Color(0xFFB0AAA2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final FeedbackCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = selected ? colors.accent : colors.textMed;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : colors.bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? colors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                category.label,
                style: AppText.sans(
                  size: 11.5,
                  weight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Multiline sibling of [AppTextField] (same fill / radius / border recipe).
class _MultilineField extends StatelessWidget {
  const _MultilineField({required this.controller, this.hint});

  final TextEditingController controller;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.rowInput),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 5,
      textInputAction: TextInputAction.newline,
      style: AppText.sans(size: 13, height: 1.45, color: colors.text),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.bg,
        hintText: hint,
        hintStyle: AppText.sans(size: 13, height: 1.45, color: colors.textDim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: border(colors.border),
        focusedBorder: border(colors.accent),
        border: border(colors.border),
      ),
    );
  }
}
