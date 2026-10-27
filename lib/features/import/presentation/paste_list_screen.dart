import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../settings/presentation/widgets/settings_scaffold.dart';
import '../providers/import_session.dart';
import 'widgets/import_widgets.dart';

/// Reminder import → Paste a list. One reminder per line; a day or time on
/// the line puts it there (services/device_import/text_list_parser.dart).
class PasteListScreen extends ConsumerStatefulWidget {
  const PasteListScreen({super.key});

  @override
  ConsumerState<PasteListScreen> createState() => _PasteListScreenState();
}

class _PasteListScreenState extends ConsumerState<PasteListScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Nothing to paste yet — copy your list first.'),
          ),
        );
      return;
    }
    // Added below what is already there, so two lists can be pasted in turn.
    final current = _controller.text.trimRight();
    setState(() => _controller.text = current.isEmpty ? text : '$current\n$text');
  }

  void _preview() {
    if (!_hasText) return;
    FocusScope.of(context).unfocus();
    unawaited(ref.read(importSessionProvider.notifier).startPastedList(_controller.text));
    // Replaces this screen, so "Done" on the review lands back on Reminder
    // import rather than on the text that was just imported.
    unawaited(context.pushReplacement(Routes.importReview));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SettingsScaffold(
      title: 'Paste a list',
      children: [
        const ImportCaption(
          'One reminder per line. Add a day or time and it lands there — '
          '"Essay draft fri", "Lab report 30/10 5pm", "Pay fees by Nov 3". '
          'Lines without one go on today.',
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: colors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 6, 15, 6),
            child: TextField(
              controller: _controller,
              minLines: 8,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: colors.accent,
              onChanged: (_) => setState(() {}),
              style: AppText.sans(size: 13.5, height: 1.5, color: colors.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Essay draft fri\nLab report 30/10 5pm\nReturn library books',
                hintStyle: AppText.sans(size: 13.5, height: 1.5, color: colors.textDim),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Paste',
                icon: Icons.content_paste,
                ghost: true,
                onPressed: () => unawaited(_pasteClipboard()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: 'Preview',
                enabled: _hasText,
                onPressed: _preview,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
