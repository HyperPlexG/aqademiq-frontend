import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/study_tag_mark.dart';

/// The created tag returned by [showAddTagSheet] (name + chosen swatch).
typedef TagDraft = ({String label, Color color});

/// FRAMES `settings-addtag` — the "New study tag" sheet on the floating,
/// keyboard-aware shell. Returns the [TagDraft] on "Add tag", or null on
/// dismiss. Preset to name "Tutorial" with the pink (`#e85476`) swatch.
Future<TagDraft?> showAddTagSheet(BuildContext context) {
  return showAppBottomSheet<TagDraft>(
    context,
    title: 'New study tag',
    child: const _AddTagBody(),
  );
}

/// The seven tag palette colours (prototype order).
const _palette = <Color>[
  Color(0xFF5CBBFF),
  Color(0xFF6B5CF0),
  Color(0xFFE85476),
  Color(0xFF2A9D6B),
  Color(0xFFE8A430),
  Color(0xFFC0497B),
  Color(0xFF9AA3B2),
];

class _AddTagBody extends StatefulWidget {
  const _AddTagBody();

  @override
  State<_AddTagBody> createState() => _AddTagBodyState();
}

class _AddTagBodyState extends State<_AddTagBody> {
  final _controller = TextEditingController(text: 'Tutorial');
  Color _selected = const Color(0xFFE85476);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _controller.text.trim();
    if (label.isEmpty) return;
    Navigator.of(context).pop((label: label, color: _selected));
  }

  Widget _label(String text, {double bottom = 7}) => Padding(
        padding: EdgeInsets.fromLTRB(2, 0, 2, bottom),
        child: Text(
          text,
          style: AppText.sans(size: 17, weight: FontWeight.w700, color: context.colors.textMed),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _PreviewChip(
            name: name.isEmpty ? 'Tag' : name,
            color: _selected,
          ),
        ),
        const SizedBox(height: 18),
        _label('Name'),
        AppTextField(controller: _controller),
        const SizedBox(height: 18),
        _label('Colour', bottom: 11),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final c in _palette)
                _Swatch(
                  color: c,
                  selected: c == _selected,
                  onTap: () => setState(() => _selected = c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Add tag', enabled: name.isNotEmpty, onPressed: _submit),
      ],
    );
  }
}

/// Centred live preview of the tag being created: a 36 white chip with the
/// hairline and card shadow, its mark and a 17/700 name.
class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StudyTagMark(label: name, color: color, dot: 9),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// One 32 colour circle in the palette row. Selected adds a white gap + a
/// colour ring (two box-shadows) and a white check.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = context.colors.surface;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // Painted in order, so the outer colour ring goes first and the
            // white gap over it (CSS lists them the other way round).
            boxShadow: selected
                ? [
                    BoxShadow(color: color, spreadRadius: 4),
                    BoxShadow(color: surface, spreadRadius: 2),
                  ]
                : null,
          ),
          child: selected ? const Ic('check', size: 20, color: Color(0xFFFFFFFF)) : null,
        ),
      ),
    );
  }
}
