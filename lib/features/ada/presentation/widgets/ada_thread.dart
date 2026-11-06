import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/repositories/ada_repository.dart';
import '../../../../shared/mascot/ada_mascot.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../../shared/widgets/markdown_text.dart';
import 'ada_look.dart';
import 'think_mark.dart';

// The rows of Ada's thread (v11 `AdaSay`, `YouSay`, `AdaThinking`).

/// The space a reply's text starts in from the edge: the 24 cube and its 9 gap.
const double kAdaSayIndent = 33;

/// Ada speaking: her 24 cube, then the reply as plain text on the page, with
/// whatever she attached to it (a plan button, proposal cards) underneath.
class AdaSay extends StatelessWidget {
  const AdaSay({super.key, required this.text, this.expr = AdaExpr.happy, this.below = const []});

  /// Markdown, as Ada writes it.
  final String text;
  final AdaExpr expr;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final look = AdaLook.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: AdaMascot(size: 24, expr: expr),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (text.trim().isNotEmpty)
                MarkdownText(
                  text,
                  style: AppText.sans(size: 17, weight: FontWeight.w400, height: 1.55, color: look.reply),
                  muted: colors.textMed,
                  accent: colors.accent,
                ),
              ...below,
            ],
          ),
        ),
      ],
    );
  }
}

/// The student's message: a grey bubble on the right, never Markdown, so a
/// literal asterisk stays an asterisk.
class YouSay extends StatelessWidget {
  const YouSay({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final look = AdaLook.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 262),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: look.bubble,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: AppText.sans(size: 17, weight: FontWeight.w400, height: 1.5, color: look.bubbleInk),
        ),
      ),
    );
  }
}

/// "Ada is thinking", with the wait made visible (v11 `ada-thinking`).
///
/// An Ada turn is several provider calls and can legitimately run past a
/// minute when it opens an attachment. A static line for that long reads as a
/// hang; the state-mark loop keeps moving without claiming progress it cannot
/// measure, which a spinner or a percentage would.
class AdaThinking extends StatelessWidget {
  const AdaThinking({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      label: 'Ada is thinking',
      excludeSemantics: true,
      child: Row(
        children: [
          const AdaMascot(size: 24, expr: AdaExpr.focused),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'Ada is thinking',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(size: 17, weight: FontWeight.w400, color: colors.textMed),
            ),
          ),
          const SizedBox(width: 9),
          ThinkMark(color: colors.accent),
        ],
      ),
    );
  }
}

/// Under a message whose reply the student stopped waiting for. It says only
/// what happened on this phone — the server may still finish the reply.
class AdaStoppedNote extends StatelessWidget {
  const AdaStoppedNote({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: kAdaSayIndent),
      child: Text(
        'You stopped this reply.',
        style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed),
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
class AdaErrorNote extends StatelessWidget {
  const AdaErrorNote({
    super.key,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Ic('error_outline', color: colors.danger),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
            decoration: BoxDecoration(
              // Tinted rather than solid danger: this is information, not an
              // alarm, and the chat should not turn red because a request
              // timed out.
              color: colors.danger.alpha8(0x14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    message,
                    style: AppText.sans(size: 17, weight: FontWeight.w400, height: 1.45, color: colors.text),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NoteButton(label: 'Retry', color: colors.accent, strong: true, onTap: onRetry),
                    _NoteButton(label: 'Dismiss', color: colors.textMed, strong: false, onTap: onDismiss),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({required this.label, required this.color, required this.strong, required this.onTap});

  final String label;
  final Color color;
  final bool strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(right: 18),
          child: Text(
            label,
            style: AppText.sans(size: 15, weight: strong ? FontWeight.w800 : FontWeight.w600, color: color),
          ),
        ),
      ),
    );
  }
}

/// "Add to my plan" under a reply that proposed a schedule — the legacy,
/// pre-agent path. A 44 ink capsule, the design's bar-control size.
class AdaApplyPlanButton extends StatelessWidget {
  const AdaApplyPlanButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(15, 0, 18, 0),
            decoration: BoxDecoration(
              color: colors.ink,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Ic('add', size: 19, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Add to my plan',
                  style: AppText.sans(size: 15, weight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Files staged for the next message, above the text box.
class AdaAttachmentRow extends StatelessWidget {
  const AdaAttachmentRow({
    super.key,
    required this.uploading,
    required this.attachments,
    required this.onRemove,
  });

  /// Height of the row, for the thread's bottom inset.
  static const double height = 36;

  final bool uploading;
  final List<AdaAttachmentRef> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          for (final a in attachments) ...[
            _AttachmentChip(name: a.name, onRemove: () => onRemove(a.key)),
            const SizedBox(width: 6),
          ],
          if (uploading)
            _Chip(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                ),
                const SizedBox(width: 7),
                Text('Uploading…', style: AppText.sans(size: 15, weight: FontWeight.w500, color: colors.textMed)),
              ],
            ),
        ],
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
    return _Chip(
      maxWidth: 240,
      children: [
        Ic('attach_file', size: 16, color: colors.accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.sans(size: 15, color: colors.text),
          ),
        ),
        const SizedBox(width: 2),
        Semantics(
          button: true,
          label: 'Remove $name',
          excludeSemantics: true,
          onTap: onRemove,
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 32,
              height: 36,
              child: Center(child: Ic('close', size: 16, color: colors.textMed)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.children, this.maxWidth = double.infinity});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
