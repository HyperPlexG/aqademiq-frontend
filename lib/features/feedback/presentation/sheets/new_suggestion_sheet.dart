import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/launch_external.dart';
import '../../../../data/models/enums.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/feedback_bits.dart';

/// What the "Make a suggestion" sheet returns to the board screen.
typedef FeedbackDraft = ({
  String title,
  String body,
  FeedbackCategory category,
});

/// The "Make a suggestion" composer (v11 `feedback-suggest`): category picker,
/// title, optional details, and a direct-support nudge when Bug is selected.
/// [initial] prefills the form (used to retry a draft after a failed submit).
Future<FeedbackDraft?> showNewSuggestionSheet(
  BuildContext context, {
  FeedbackDraft? initial,
}) {
  return showAppBottomSheet<FeedbackDraft>(
    context,
    title: 'Make a suggestion',
    subtitle: 'Share an idea. The community votes on what gets built.',
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
              if (category != FeedbackCategory.values.first) const SizedBox(width: 7),
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
        const SizedBox(height: 16),
        const _Label('Title'),
        _SheetField(
          controller: _title,
          hint: 'One clear sentence',
          autofocus: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 15),
        const _Label('Details (optional)'),
        _SheetField(
          controller: _body,
          hint: 'What problem does it solve? How should it work?',
          multiline: true,
        ),
        if (_category == FeedbackCategory.bug) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
            decoration: BoxDecoration(
              color: colors.danger.alpha8(0x14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Ic('bug_report', size: 20, color: colors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Blocked by a bug right now? Email the team and we will help directly.',
                    style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.4, color: colors.text),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(
                    openExternal(
                      context,
                      Uri.parse('mailto:support@aqademiq.com?subject=Bug report'),
                    ),
                  ),
                  child: Text(
                    'Email →',
                    style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Share suggestion',
          enabled: _canSubmit,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// The 12/800 field caption (v11: 0.08em, dim).
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text.toUpperCase(),
        style: AppText.sans(
          size: 12,
          weight: FontWeight.w800,
          letterSpacing: AppText.em(0.08, 12),
          color: context.colors.textDim,
        ),
      ),
    );
  }
}

/// A kind tile: Feature / Improvement / Bug (v11: radius 12, accent-soft when
/// chosen, an 18 glyph and 15/700).
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
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.hilite,
            borderRadius: BorderRadius.circular(12),
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
                Ic(category.icon, size: 18, color: fg),
                const SizedBox(width: 5),
                Text(
                  category.label,
                  style: AppText.sans(size: 15, weight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet's input (v11 `feedback-suggest`): a hilite well at rest, white
/// with the accent hairline while typing. Radius 12, 17 text.
class _SheetField extends StatefulWidget {
  const _SheetField({
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.multiline = false,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? hint;
  final bool autofocus;
  final bool multiline;
  final TextInputAction? textInputAction;

  @override
  State<_SheetField> createState() => _SheetFieldState();
}

class _SheetFieldState extends State<_SheetField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final focused = _focus.hasFocus;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      minLines: widget.multiline ? 2 : 1,
      maxLines: widget.multiline ? 5 : 1,
      textInputAction: widget.multiline ? TextInputAction.newline : widget.textInputAction,
      style: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.45, color: colors.text),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: focused ? colors.surface : colors.hilite,
        hintText: widget.hint,
        hintMaxLines: 2,
        hintStyle: AppText.sans(size: 17, weight: FontWeight.w500, height: 1.45, color: colors.textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: border(Colors.transparent),
        focusedBorder: border(colors.accent),
        border: border(Colors.transparent),
      ),
    );
  }
}
