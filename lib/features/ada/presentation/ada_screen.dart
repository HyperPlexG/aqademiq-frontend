import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/ada_action.dart';
import '../../../data/models/ada_message.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/ada_repository.dart';
import '../../../data/sources/ada_source.dart';
import '../../../services/haptics/haptics_service.dart';
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
      // Ada's entire budget is 1 (§7): "'Plan my week' applied to the plan".
      // Message send, message arrival and streaming tokens are all zero — none
      // of them is a state change the user caused, and a chat that buzzes as it
      // types is the fastest way to lose the channel.
      //
      // Reuses `taskCreated` rather than minting a 23rd Tier 2 event: what just
      // happened is that tasks appeared on the plan, which is the same state
      // change the Plan screen confirms with the same light single. Spec §3
      // caps the vocabulary at the events it lists, and this needs no new one.
      ref.read(hapticsProvider).taskCreated();
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

  /// Approve one of Ada's proposed changes. Nothing was written until now — the
  /// server executes it here, then lets the agent carry on from the result.
  Future<void> _approve(AdaAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    final applied = await ref.read(adaChatProvider.notifier).approveAction(action.id);
    if (!mounted) return;
    if (applied) {
      _refreshAffected(action.resource);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't apply “${action.title}”.")),
      );
    }
  }

  Future<void> _reject(AdaAction action) =>
      ref.read(adaChatProvider.notifier).rejectAction(action.id);

  Future<void> _decideAll({required bool approve}) async {
    final messenger = ScaffoldMessenger.of(context);
    final applied = await ref.read(adaChatProvider.notifier).decideAll(approve: approve);
    if (!mounted) return;
    if (approve) {
      _refreshAffected('task');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            applied == 0
                ? "Couldn't apply those changes."
                : '$applied change${applied == 1 ? '' : 's'} applied ✓',
          ),
        ),
      );
    }
  }

  /// Ada writes through the same services the rest of the app reads from, so an
  /// applied change has to invalidate those caches or the plan looks unchanged.
  void _refreshAffected(String resource) {
    if (resource == 'task' || resource == 'subject' || resource == 'semester') {
      ref.invalidate(dayTasksProvider);
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
                    error: chat.error,
                    onRetry: () => unawaited(
                      ref.read(adaChatProvider.notifier).retryLast(),
                    ),
                    onDismissError:
                        ref.read(adaChatProvider.notifier).clearError,
                    onApplyPlan: _applyPlan,
                    actionsByMessage: chat.actionsByMessage,
                    decidingIds: chat.decidingActionIds,
                    onApprove: _approve,
                    onReject: _reject,
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, inputBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chat.outstandingActions.length > 1)
                  _DecideAllBar(
                    count: chat.outstandingActions.length,
                    busy: chat.decidingActionIds.isNotEmpty,
                    onApproveAll: () => unawaited(_decideAll(approve: true)),
                    onRejectAll: () => unawaited(_decideAll(approve: false)),
                  ),
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
    required this.error,
    required this.onRetry,
    required this.onDismissError,
    required this.onApplyPlan,
    required this.actionsByMessage,
    required this.decidingIds,
    required this.onApprove,
    required this.onReject,
  });
  final List<AdaMessage> messages;
  final bool typing;

  /// Why the last turn failed, or null. Rendered in the transcript rather than
  /// as a snackbar: a snackbar for a minute-long request is gone before the
  /// user looks back at the screen, and this is the answer to "what happened
  /// to my message".
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onDismissError;
  final ValueChanged<String> onApplyPlan;
  final Map<String, List<AdaAction>> actionsByMessage;
  final Set<String> decidingIds;
  final ValueChanged<AdaAction> onApprove;
  final ValueChanged<AdaAction> onReject;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      children: [
        for (final m in messages)
          _Bubble(
            message: m,
            onApplyPlan: onApplyPlan,
            actions: actionsByMessage[m.id] ?? const [],
            decidingIds: decidingIds,
            onApprove: onApprove,
            onReject: onReject,
          ),
        if (typing) const _TypingBubble(),
        if (error != null)
          _ErrorBubble(
            message: error!,
            onRetry: onRetry,
            onDismiss: onDismissError,
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onApplyPlan,
    this.actions = const [],
    this.decidingIds = const {},
    required this.onApprove,
    required this.onReject,
  });
  final AdaMessage message;
  final ValueChanged<String> onApplyPlan;
  final List<AdaAction> actions;
  final Set<String> decidingIds;
  final ValueChanged<AdaAction> onApprove;
  final ValueChanged<AdaAction> onReject;

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
                for (final action in actions) ...[
                  const SizedBox(height: 6),
                  _ActionCard(
                    action: action,
                    busy: decidingIds.contains(action.id),
                    onApprove: () => onApprove(action),
                    onReject: () => onReject(action),
                  ),
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

/// A change Ada wants to make, with the user's approve/decline gate.
///
/// Nothing behind this card has happened yet: the backend holds it as a pending
/// action and applies it only when Approve is tapped. Once decided the card
/// freezes into a receipt so the conversation stays readable on reload.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final AdaAction action;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Color _accentFor(AppColors colors) => switch (action.operation) {
        AdaActionOperation.delete => const Color(0xFFFF5C7C),
        AdaActionOperation.create => colors.accent,
        AdaActionOperation.update => colors.accent,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = _accentFor(colors);
    final decided = action.status.isDecided;

    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: decided ? colors.border : accent.alpha8(0x55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.alpha8(0x1A),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  action.operation.label.toUpperCase(),
                  style: AppText.sans(size: 8, weight: FontWeight.w800, color: accent),
                ),
              ),
              const Spacer(),
              if (decided) _StatusChip(status: action.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action.title,
            style: AppText.sans(size: 12, weight: FontWeight.w700, height: 1.35, color: colors.text),
          ),
          if (action.fields.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final f in action.fields) _FieldRow(field: f),
          ],
          if (action.warning != null) ...[
            const SizedBox(height: 6),
            Text(
              action.warning!,
              style: AppText.sans(size: 10, height: 1.35, color: const Color(0xFFFF5C7C)),
            ),
          ],
          if (action.status.isFailed && action.error != null) ...[
            const SizedBox(height: 6),
            Text(
              action.error!,
              style: AppText.sans(size: 10, height: 1.35, color: const Color(0xFFFF5C7C)),
            ),
          ],
          if (!decided) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Approve',
                    filled: true,
                    accent: accent,
                    busy: busy,
                    onTap: busy ? null : onApprove,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: 'Decline',
                    filled: false,
                    accent: colors.textMed,
                    busy: false,
                    onTap: busy ? null : onReject,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.field});
  final AdaActionField field;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              field.label,
              style: AppText.sans(size: 10, color: colors.textDim),
            ),
          ),
          Expanded(
            child: field.isChange
                // Show the old value struck through so a change reads as a
                // change, not as a fresh value the user has to reason about.
                ? Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        field.from!,
                        style: AppText.sans(size: 10, color: colors.textDim).copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text('  →  ', style: AppText.sans(size: 10, color: colors.textDim)),
                      Text(
                        field.to ?? '—',
                        style: AppText.sans(size: 10, weight: FontWeight.w700, color: colors.text),
                      ),
                    ],
                  )
                : Text(
                    field.to ?? '—',
                    style: AppText.sans(size: 10, weight: FontWeight.w700, color: colors.text),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final AdaActionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, color) = switch (status) {
      AdaActionStatus.executed => ('Applied ✓', const Color(0xFF34C759)),
      AdaActionStatus.rejected => ('Declined', colors.textDim),
      AdaActionStatus.failed => ('Failed', const Color(0xFFFF5C7C)),
      _ => ('Done', colors.textDim),
    };
    return Text(
      label,
      style: AppText.sans(size: 9, weight: FontWeight.w800, color: color),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.accent,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final Color accent;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: filled ? null : Border.all(color: colors.border),
        ),
        child: busy
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: filled ? Colors.white : accent,
                ),
              )
            : Text(
                label,
                style: AppText.sans(
                  size: 11,
                  weight: FontWeight.w800,
                  color: filled ? Colors.white : colors.textMed,
                ),
              ),
      ),
    );
  }
}

/// Shown above the input when Ada has proposed several changes at once.
class _DecideAllBar extends StatelessWidget {
  const _DecideAllBar({
    required this.count,
    required this.busy,
    required this.onApproveAll,
    required this.onRejectAll,
  });

  final int count;
  final bool busy;
  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: colors.accent.alpha8(0x14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.accent.alpha8(0x33)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count changes waiting',
                style: AppText.sans(size: 11, weight: FontWeight.w700, color: colors.text),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onRejectAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Decline all',
                  style: AppText.sans(size: 11, weight: FontWeight.w700, color: colors.textMed),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: busy ? null : onApproveAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: busy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white),
                      )
                    : Text(
                        'Approve all',
                        style: AppText.sans(size: 11, weight: FontWeight.w800, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Ada is thinking", with the wait made visible.
///
/// An Ada turn is several provider calls and can legitimately run past a
/// minute when it opens an attachment. A static line for that long reads as a
/// hang — the thing you look at to decide whether the app is still alive. A
/// loop that keeps moving answers that question without claiming progress it
/// cannot measure, which a spinner or a percentage would.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  /// Slow enough to read as breathing rather than loading. A fast pulse on a
  /// 60-second wait is agitating; this one is meant to be ignorable.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  /// One dot's position in the travelling wave, 0 at rest and 1 at the peak.
  /// [phase] staggers each dot so the crest moves left to right.
  double _lift(double t, double phase) {
    final local = (t - phase) % 1.0;
    // The crest occupies the first 45% of the cycle; the rest is the pause that
    // stops three dots looking like a stutter.
    if (local > 0.45) return 0;
    return math.sin((local / 0.45) * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Honour the OS "reduce motion" setting. Vestibular triggers aside, this is
    // the one widget on screen during a long wait, so a user who has asked for
    // stillness should not be given the most persistent movement in the app.
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: still
                ? const AdaMascot(size: 22)
                : AnimatedBuilder(
                    animation: _wave,
                    builder: (context, child) => Transform.scale(
                      // Barely there — enough to read as alive, not as a pulse.
                      scale: 1 + 0.05 * _lift(_wave.value, 0),
                      child: child,
                    ),
                    child: const AdaMascot(size: 22),
                  ),
          ),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ada is thinking',
                  style: AppText.sans(size: 12, color: colors.textMed),
                ),
                const SizedBox(width: 6),
                if (still)
                  Text('…', style: AppText.sans(size: 12, color: colors.textMed))
                else
                  AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          _Dot(lift: _lift(_wave.value, i * 0.16), color: colors.accent),
                        ],
                      ],
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

/// A failed turn, said out loud in the transcript.
///
/// Sits where Ada's reply would have been, because that is where the user is
/// looking when they wonder what happened to their message. A snackbar would be
/// wrong here twice over: an Ada turn can take a minute, so the snackbar is long
/// gone by the time anyone looks back, and it carries no way to retry.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.error_outline, size: 17, color: colors.danger),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                // Tinted rather than solid danger: this is information, not an
                // alarm, and the chat should not turn red because a request
                // timed out.
                color: colors.danger.alpha8(0x14),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(3),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: AppText.sans(size: 12.5, height: 1.4, color: colors.text),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Retry',
                          style: AppText.sans(
                            size: 12,
                            weight: FontWeight.w800,
                            color: colors.accent,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onDismiss,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Dismiss',
                          style: AppText.sans(size: 12, color: colors.textMed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dot of the thinking indicator. [lift] is 0 at rest, 1 at the crest.
class _Dot extends StatelessWidget {
  const _Dot({required this.lift, required this.color});

  final double lift;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, -2.5 * lift),
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          // Never fully transparent: a dot that vanishes makes the row change
          // width to the eye, which reads as jitter rather than rhythm.
          color: color.withValues(alpha: 0.35 + 0.65 * lift),
          shape: BoxShape.circle,
        ),
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
