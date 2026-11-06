import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Ada's own colourway (v11 `adaTheme`), layered on the app tokens.
///
/// The chat follows Gemini's: a grey prompt bubble, the reply as plain text on
/// the page, and a floating translucent text box. The intro state adds a glow
/// from the bottom, tinted to the accent.
@immutable
class AdaLook {
  const AdaLook._({
    required this.box,
    required this.edge,
    required this.lift,
    required this.placeholder,
    required this.bubble,
    required this.bubbleInk,
    required this.reply,
    required this.speakBg,
    required this.speakInk,
    required this.added,
    required this.glowCore,
    required this.glowMid,
  });

  factory AdaLook.of(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The design's dark speak button (#2a2170) is drawn for the violet accent;
    // any other accent keeps its own soft tint rather than borrowing violet.
    final violet = colors.accent == AppAccent.violet.color;
    return AdaLook._(
      box: dark ? const Color(0xEB1F1F21) : const Color(0xDBFFFFFF),
      edge: dark ? const Color(0x14FFFFFF) : null,
      lift: dark
          ? const <BoxShadow>[]
          : const [BoxShadow(color: Color(0x14000000), blurRadius: 26, offset: Offset(0, 6))],
      placeholder: dark ? const Color(0xFF999999) : const Color(0xFF6F7174),
      // The design's light bubble (#f1f0f0) is one step under its #fcfcfc
      // page; on the app's warmer page it would all but vanish, so light mode
      // takes the next fill down, as the design does for fills on the page.
      bubble: dark ? const Color(0xFF212121) : colors.hilite,
      bubbleInk: dark ? const Color(0xFFE0E0E0) : colors.text,
      reply: dark ? const Color(0xFFE0E0E0) : colors.text,
      speakBg: dark && violet ? const Color(0xFF2A2170) : colors.accentSoft,
      speakInk: dark && violet ? const Color(0xFFE6E2FF) : colors.text,
      // `adaGreen`: assignment ink, 5.3:1 on white.
      added: dark ? colors.success : const Color(0xFF1D7A52),
      glowCore: colors.accent.alpha8(dark ? 0x5E : 0x4D),
      glowMid: colors.accent.alpha8(dark ? 0x22 : 0x1C),
    );
  }

  /// The glass the input and the proposal tray are made of.
  final Color box;

  /// Hairline round the glass (dark only).
  final Color? edge;

  /// The glass's shadow (light only).
  final List<BoxShadow> lift;

  final Color placeholder;

  /// The student's message bubble and its text.
  final Color bubble;
  final Color bubbleInk;

  /// Ada's reply text, and the suggestion rows.
  final Color reply;

  /// The round action button (speak / send / stop) and the Upload pill.
  final Color speakBg;
  final Color speakInk;

  /// "Added to today".
  final Color added;

  /// The intro glow's centre and middle stops.
  final Color glowCore;
  final Color glowMid;
}
