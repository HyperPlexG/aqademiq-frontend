import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/ada_message.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/ada_repository.dart';
import '../../../data/sources/ada_source.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/dismiss_keyboard.dart';
import '../../../shared/widgets/markdown_text.dart';
import '../../plan/providers/plan_providers.dart';
import 'widgets/chat_history_sheet.dart';

/// FRAMES `ada-empty` / `ada-chat` — the Ada tab (intro when empty, conversation
/// once started). History opens as a slide-over.
class AdaScreen extends ConsumerStatefulWidget {
  const AdaScreen({super.key});

  @override
  ConsumerState<AdaScreen> createState() => _AdaScreenState();
}

class _AdaScreenState extends ConsumerState<AdaScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final chat = ref.read(adaChatProvider);
    final value = (text ?? _input.text).trim();
    if (value.isEmpty && chat.pendingAttachments.isEmpty) return;
    _input.clear();
    unawaited(ref.read(adaChatProvider.notifier).send(value));
  }

  Future<void> _applyPlan(String messageId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adaChatProvider.notifier).applyPlan(messageId);
      ref.invalidate(dayTasksProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to your plan ✓')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't apply this plan.")),
      );
    }
  }

  Future<void> _pickAndUpload() async {
    const typeGroup = XTypeGroup(
      label: 'Documents',
      // iOS filters by UTIs; without them the picker greys out every file.
      extensions: <String>['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt', 'md'],
      mimeTypes: <String>['application/pdf', 'text/plain'],
      uniformTypeIdentifiers: <String>[
        'com.adobe.pdf',
        'public.plain-text',
        'public.text',
        'net.daringfireball.markdown',
        'com.microsoft.word.doc',
        'org.openxmlformats.wordprocessingml.document',
        'com.microsoft.powerpoint.ppt',
        'org.openxmlformats.presentationml.presentation',
        'public.image',
      ],
    );
    // Multi-select when the platform supports it; each file is staged only —
    // nothing is sent until the user taps Send.
    final messenger = ScaffoldMessenger.of(context);
    final files = await openFiles(acceptedTypeGroups: const [typeGroup]);
    if (files.isEmpty) return;

    final notifier = ref.read(adaChatProvider.notifier);
    for (final file in files) {
      try {
        await notifier.stageAttachment(file);
      } on Object {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text("Couldn't upload ${file.name}. Try again.")),
        );
      }
    }
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(adaChatProvider);
    // Sit above the keyboard when typing, otherwise above the floating nav.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final inputBottom = keyboard > 0 ? keyboard + 8 : AppScaffold.navClearanceOf(context);

    return DismissKeyboard(
      child: Column(
        children: [
          _Header(
            onHistory: () => unawaited(showChatHistory(context)),
            onUpload: chat.uploading ? null : () => unawaited(_pickAndUpload()),
            uploading: chat.uploading,
          ),
          Expanded(
            child: chat.isEmpty
                ? _EmptyState(onSuggest: _send)
                : _MessageList(
                    messages: chat.messages,
                    typing: chat.typing,
                    onApplyPlan: _applyPlan,
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, inputBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chat.uploading || chat.pendingAttachments.isNotEmpty)
                  _AttachmentPreview(
                    uploading: chat.uploading,
                    attachments: chat.pendingAttachments,
                    onRemove: (key) =>
                        ref.read(adaChatProvider.notifier).removePendingAttachment(key),
                  ),
                _InputBar(
                  controller: _input,
                  focusNode: _focus,
                  compact: !chat.isEmpty,
                  onSend: _send,
                  onSpeak: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voice input is coming soon.')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onHistory,
    required this.onUpload,
    this.uploading = false,
  });
  final VoidCallback onHistory;
  final VoidCallback? onUpload;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.border))),
      child: Row(
        children: [
          GestureDetector(
            onTap: onHistory,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle, boxShadow: colors.cardShadow),
              child: Icon(Icons.menu, size: 15, color: colors.text),
            ),
          ),
          const SizedBox(width: 9),
          Text('Ada', style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.text)),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onUpload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: uploading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: colors.textMed,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Uploading…',
                          style: AppText.sans(
                            size: 10,
                            weight: FontWeight.w700,
                            color: colors.textDim,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '↑ Upload',
                      style: AppText.sans(
                        size: 10,
                        weight: FontWeight.w700,
                        color: onUpload == null ? colors.textDim : colors.text,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggest});
  final ValueChanged<String> onSuggest;

  static const _chips = ['Plan my week', "I'm overwhelmed", 'Break this down', 'Deadline help'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AdaMascot(size: 72),
        const SizedBox(height: 16),
        Text(
          "Drop your thoughts.\nI'll turn them into a plan.",
          textAlign: TextAlign.center,
          style: AppText.sans(size: 17, weight: FontWeight.w700, height: 1.4, color: colors.text),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in _chips)
                GestureDetector(
                  onTap: () => onSuggest(c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: colors.accent.alpha8(0x44)),
                    ),
                    child: Text(c, style: AppText.sans(size: 10, color: colors.accent)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.typing,
    required this.onApplyPlan,
  });
  final List<AdaMessage> messages;
  final bool typing;
  final ValueChanged<String> onApplyPlan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      children: [
        for (final m in messages) _Bubble(message: m, onApplyPlan: onApplyPlan),
        if (typing) const _TypingBubble(),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onApplyPlan});
  final AdaMessage message;
  final ValueChanged<String> onApplyPlan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUser = message.role == AdaRole.user;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: isUser ? 170 : 185),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isUser ? colors.accent : colors.bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isUser ? 12 : 3),
          bottomRight: Radius.circular(isUser ? 3 : 12),
        ),
      ),
      child: isUser
          // The user's own text is never Markdown — render it verbatim so a
          // literal asterisk stays an asterisk.
          ? Text(
              message.text,
              style: AppText.sans(size: 12, height: 1.55, color: Colors.white),
            )
          : MarkdownText(
              message.text,
              style: AppText.sans(size: 12, height: 1.55, color: colors.text),
              muted: colors.textMed,
              accent: colors.accent,
            ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const Padding(padding: EdgeInsets.only(top: 2), child: AdaMascot(size: 22)),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                if (!isUser && message.hasPlan) ...[
                  const SizedBox(height: 6),
                  _ApplyPlanButton(onTap: () => onApplyPlan(message.id)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add to my plan" CTA shown under an Ada message that proposed a schedule.
class _ApplyPlanButton extends StatelessWidget {
  const _ApplyPlanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add_check, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Add to my plan',
              style: AppText.sans(size: 11, weight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: AdaMascot(size: 22)),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(3),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text('Ada is thinking…', style: AppText.sans(size: 12, color: colors.textMed)),
          ),
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.uploading,
    required this.attachments,
    required this.onRemove,
  });

  final bool uploading;
  final List<AdaAttachmentRef> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final a in attachments) ...[
              _AttachmentChip(
                name: a.name,
                onRemove: () => onRemove(a.key),
              ),
              const SizedBox(width: 6),
            ],
            if (uploading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Uploading…',
                      style: AppText.sans(size: 11, color: colors.textMed),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 13, color: colors.accent),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 11, color: colors.text),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: colors.textMed),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.compact,
    required this.onSend,
    required this.onSpeak,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool compact;
  final VoidCallback onSend;
  final VoidCallback onSpeak;

  static const _ink = Color(0xFF1A1320);

  /// Soft keyboard Return inserts a newline; hardware Cmd/Ctrl+Enter still sends.
  static const int _minLines = 1;
  static const int _maxLines = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: <ShortcutActivator, VoidCallback>{
                const SingleActivator(LogicalKeyboardKey.enter, meta: true): onSend,
                const SingleActivator(LogicalKeyboardKey.enter, control: true): onSend,
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppText.sans(size: 12, color: colors.text),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: _minLines,
                maxLines: _maxLines,
                // Intentionally no onSubmitted — Enter must insert a newline, not send.
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: compact ? 'Ask Ada anything...' : "What's on your mind?",
                  hintStyle: AppText.sans(size: 12, color: colors.textDim),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Voice capture isn't ready yet — the pill is honest about that. Text
          // still sends via the arrow, which is always present.
          if (!compact) ...[
            GestureDetector(
              onTap: onSpeak,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _ink.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('◈', style: TextStyle(fontSize: 12, color: Colors.white, height: 1)),
                    const SizedBox(width: 5),
                    Text('Speak', style: AppText.sans(size: 11, weight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _ink, shape: BoxShape.circle),
              child: const Text('↑', style: TextStyle(fontSize: 14, color: Colors.white, height: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
