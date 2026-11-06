import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../shared/widgets/ic.dart';
import 'ada_look.dart';

// The frame around Ada's thread (v11 `AdaHead`, `AdaFade`, `AdaInput`,
// `ProposalTray`): a 72 header on the page colour, eased fades where the
// thread scrolls under it and under the glass, and the glass itself.

/// Height of the header: 16 + a 44 control + 12.
const double kAdaHeaderHeight = 72;

/// The fade under the header (`ADA_EDGE_H`). The thread starts 2 below it.
const double kAdaEdgeFade = 28;

/// The floating text box: 72 tall, fully round, 39 in from each side.
const double kAdaInputHeight = 72;
const double kAdaGlassInset = 39;

/// The proposal tray: 56 tall, docked 8 above the text box.
const double kAdaTrayHeight = 56;
const double kAdaTrayGap = 8;

/// The fade ramp every Ada edge eases through (`ADA_RAMP`): position → alpha.
const List<(double, double)> _ramp = [(0.0, 1.0), (0.22, 0.86), (0.48, 0.58), (0.74, 0.24), (1.0, 0.0)];

/// Header: the chat-history button, "Ada", and Upload.
class AdaHeader extends StatelessWidget {
  const AdaHeader({
    super.key,
    required this.onHistory,
    required this.onUpload,
    this.uploading = false,
  });

  final VoidCallback onHistory;

  /// Null while a file is uploading.
  final VoidCallback? onUpload;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: kAdaHeaderHeight,
      color: colors.bg,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          AdaMenuButton(onTap: onHistory, label: 'Chat history'),
          const SizedBox(width: 12),
          Text('Ada', style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text)),
          const Spacer(),
          _UploadPill(onTap: onUpload, uploading: uploading),
        ],
      ),
    );
  }
}

/// The 44 round chat-history button (`AdaMenuBtn`): three stepped lines.
class AdaMenuButton extends StatelessWidget {
  const AdaMenuButton({super.key, required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            boxShadow: colors.cardShadow,
          ),
          child: CustomPaint(
            size: const Size.square(18),
            painter: _MenuGlyph(colors.text),
          ),
        ),
      ),
    );
  }
}

class _MenuGlyph extends CustomPainter {
  const _MenuGlyph(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 18;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(2.5 * s, 4.5 * s), Offset(15.5 * s, 4.5 * s), paint)
      ..drawLine(Offset(2.5 * s, 9 * s), Offset(11.5 * s, 9 * s), paint)
      ..drawLine(Offset(2.5 * s, 13.5 * s), Offset(8 * s, 13.5 * s), paint);
  }

  @override
  bool shouldRepaint(_MenuGlyph oldDelegate) => oldDelegate.color != color;
}

/// "Upload" in the accent tint (`UploadPill`).
class _UploadPill extends StatelessWidget {
  const _UploadPill({required this.onTap, required this.uploading});

  final VoidCallback? onTap;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final look = AdaLook.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: uploading ? 'Uploading' : 'Upload a file',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(15, 0, 18, 0),
          decoration: BoxDecoration(
            color: look.speakBg,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (uploading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: look.speakInk),
                )
              else
                Ic('upload', size: 19, color: look.speakInk),
              const SizedBox(width: 6),
              Text(
                uploading ? 'Uploading…' : 'Upload',
                style: AppText.sans(size: 17, weight: FontWeight.w700, color: look.speakInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page-colour wash eased through [_ramp], so the thread dissolves under the
/// header ([AdaEdgeFade.top]) and before the glass and the nav
/// ([AdaEdgeFade.bottom], solid for its first [solid] px). Never hit-tested.
class AdaEdgeFade extends StatelessWidget {
  const AdaEdgeFade.top({super.key})
      : height = kAdaEdgeFade,
        solid = 0,
        fromTop = true;

  const AdaEdgeFade.bottom({super.key, required this.height, required this.solid}) : fromTop = false;

  final double height;
  final double solid;
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    final page = context.colors.bg;
    final s = height <= 0 ? 0.0 : (solid / height).clamp(0.0, 1.0);
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                page,
                for (final (_, a) in _ramp) page.withValues(alpha: a),
              ],
              stops: [
                0,
                for (final (p, _) in _ramp) s + p * (1 - s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted glass the input and the tray are cut from: translucent fill,
/// an 18 blur of what scrolls beneath, a hairline in dark, a lift in light.
class AdaGlass extends StatelessWidget {
  const AdaGlass({super.key, required this.radius, required this.child, this.minHeight = 0});

  final double radius;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = AdaLook.of(context);
    final shape = BorderRadius.circular(radius);
    final edge = look.edge;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: look.lift),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            decoration: BoxDecoration(
              color: look.box,
              borderRadius: shape,
              border: edge == null ? null : Border.all(color: edge),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The floating text box (`AdaInput`).
///
/// Intro: "What's on your mind?" and one round button, the mic. Thread: "Ask
/// Ada anything...", a plain mic and the send arrow. While a reply is on its
/// way the arrow becomes stop ([busy]). Typed text on the intro brings the
/// send arrow too, so a typed message can always be sent.
class AdaInputBar extends StatelessWidget {
  const AdaInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.thread,
    required this.busy,
    required this.voiceAvailable,
    required this.onSend,
    required this.onSpeak,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// A conversation is on screen (as opposed to the intro).
  final bool thread;

  /// A reply is on its way: send becomes stop.
  final bool busy;

  /// False only on a phone with no speech recognizer.
  final bool voiceAvailable;
  final VoidCallback onSend;
  final VoidCallback onSpeak;
  final VoidCallback onStop;

  /// Soft keyboard Return inserts a newline; hardware Cmd/Ctrl+Enter sends.
  static const int _maxLines = 6;

  @override
  Widget build(BuildContext context) {
    final look = AdaLook.of(context);
    return AdaGlass(
      radius: kAdaInputHeight / 2,
      minHeight: kAdaInputHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final typed = value.text.trim().isNotEmpty;
            // The intro's lone button is the mic; anything else needs the
            // action button, with the mic beside it.
            final full = thread || typed || busy || !voiceAvailable;
            final gap = full ? 4.0 : 10.0;
            return Row(
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
                      style: AppText.sans(size: 17, weight: FontWeight.w400, height: 1.3, color: look.reply),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: _maxLines,
                      // Intentionally no onSubmitted — Enter must insert a
                      // newline, not send.
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        hintText: thread ? 'Ask Ada anything...' : "What's on your mind?",
                        hintMaxLines: 1,
                        hintStyle: AppText.sans(size: 17, weight: FontWeight.w400, height: 1.3, color: look.placeholder),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                if (!full)
                  _RoundAction(
                    key: const Key('ada-speak'),
                    label: 'Speak to Ada',
                    icon: 'mic_none',
                    filled: true,
                    onTap: onSpeak,
                  )
                else ...[
                  if (voiceAvailable) ...[
                    _RoundAction(
                      key: const Key('ada-speak'),
                      label: 'Speak to Ada',
                      icon: 'mic',
                      filled: false,
                      onTap: onSpeak,
                    ),
                    SizedBox(width: gap),
                  ],
                  if (busy)
                    _RoundAction(
                      key: const Key('ada-stop'),
                      label: 'Stop the reply',
                      icon: 'end',
                      filled: true,
                      onTap: onStop,
                    )
                  else
                    _RoundAction(
                      key: const Key('ada-send'),
                      label: 'Send',
                      icon: 'arrow_upward',
                      filled: true,
                      onTap: onSend,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A 40 round button in the text box: [filled] is the accent-tint action, the
/// plain one is the mic beside it.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = AdaLook.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? look.speakBg : null,
            shape: BoxShape.circle,
          ),
          child: Ic(icon, size: 20, color: filled ? look.speakInk : look.reply),
        ),
      ),
    );
  }
}

/// "3 waiting · Decline all · Approve all", docked above the text box when
/// two or more of Ada's changes wait (`ProposalTray`).
class AdaProposalTray extends StatelessWidget {
  const AdaProposalTray({
    super.key,
    required this.count,
    required this.busy,
    required this.onShow,
    required this.onDeclineAll,
    required this.onApproveAll,
  });

  final int count;
  final bool busy;

  /// Scroll to the cards this tray is counting.
  final VoidCallback onShow;
  final VoidCallback onDeclineAll;
  final VoidCallback onApproveAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AdaGlass(
      radius: kAdaTrayHeight / 2,
      child: SizedBox(
        height: kAdaTrayHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
          // At 320dp (a 242 tray) or with large text the two buttons alone
          // outgrow the row. They scale down to fit, never past a 44 slot left
          // for the count, rather than overflow; at normal sizes they draw as
          // designed. FittedBox needs the bound — a Row gives an inflexible
          // child unbounded width, so scaling the labels alone did nothing.
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: '$count changes waiting. Show them',
                    excludeSemantics: true,
                    onTap: onShow,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onShow,
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '$count waiting',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Ic('expand_less', size: 18, color: colors.textMed),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - 44)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: busy ? null : onDeclineAll,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Decline all',
                              maxLines: 1,
                              softWrap: false,
                              style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.textMed),
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: busy ? null : onApproveAll,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: colors.ink,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    'Approve all',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: AppText.sans(size: 15, weight: FontWeight.w800, color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
                    ),
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

/// The intro's glow: an ellipse 140% of the width by 58% of the height, sat on
/// the bottom edge at 62% across, the accent fading out by 72% of the way.
class AdaGlowPainter extends CustomPainter {
  const AdaGlowPainter({required this.core, required this.mid});

  final Color core;
  final Color mid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rx = size.width * 1.4;
    final ry = size.height * 0.62;
    // Fade to the accent at zero alpha, not to transparent black: an unpremul
    // ramp through black would grey the middle of the glow.
    final shader = RadialGradient(
      colors: [core, mid, core.withValues(alpha: 0)],
      stops: const [0, 0.42, 0.72],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx));
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(size.width * 0.62, size.height)
      ..scale(1, ry / rx)
      ..drawCircle(Offset.zero, rx, Paint()..shader = shader)
      ..restore();
  }

  @override
  bool shouldRepaint(AdaGlowPainter oldDelegate) => oldDelegate.core != core || oldDelegate.mid != mid;
}
