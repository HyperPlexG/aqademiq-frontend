import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/app_bottom_sheet.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Calendar import → "Calendar link". Returns the pasted link, or null.
Future<String?> showIcsLinkSheet(BuildContext context) {
  return showAppBottomSheet<String>(
    context,
    title: 'Calendar link',
    subtitle: 'Paste an iCal (.ics) or webcal link.',
    child: const _LinkBody(),
  );
}

class _LinkBody extends StatefulWidget {
  const _LinkBody();

  @override
  State<_LinkBody> createState() => _LinkBodyState();
}

class _LinkBodyState extends State<_LinkBody> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _controller.text = text);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _controller,
          hint: 'https://… or webcal://…',
          keyboardType: TextInputType.url,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            tooltip: 'Paste',
            icon: Icon(Icons.content_paste, size: 18, color: colors.textMed),
            onPressed: () => unawaited(_paste()),
          ),
        ),
        const SizedBox(height: 14),
        const _Where(
          source: 'Google Calendar',
          path: 'Settings → your calendar → Secret address in iCal format',
        ),
        const _Where(
          source: 'Outlook',
          path: 'Settings → Calendar → Shared calendars → Publish a calendar → ICS',
        ),
        const _Where(
          source: 'Moodle / Canvas',
          path: 'Calendar → Export or Calendar feed → copy the link',
        ),
        const SizedBox(height: 6),
        Text(
          'Only events in the range you pick are added, and nothing changes in the original calendar.',
          style: AppText.sans(size: 11, height: 1.5, color: colors.textMed),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Continue', onPressed: _submit),
      ],
    );
  }
}

class _Where extends StatelessWidget {
  const _Where({required this.source, required this.path});

  final String source;
  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$source  ',
              style: AppText.sans(size: 11.5, weight: FontWeight.w800, color: colors.text),
            ),
            TextSpan(
              text: path,
              style: AppText.sans(size: 11.5, height: 1.45, color: colors.textMed),
            ),
          ],
        ),
      ),
    );
  }
}
