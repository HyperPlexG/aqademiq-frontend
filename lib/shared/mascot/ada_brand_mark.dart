import 'package:flutter/widgets.dart';

/// The Aqademiq logo: Ada as the brand cube (glass, bubbles, an open smile,
/// her shadow underneath), on a transparent ground.
///
/// Use it where the app shows *the brand* (splash, welcome, headers, the share
/// card, onboarding's hint cards). Where Ada is a character with a mood (the
/// timer, chat, mood check-ins, the loader) keep `AdaMascot`, which can change
/// expression; this mark never does.
///
/// The art is `assets/images/logo.png`, rendered from the same vector as the
/// app icons (`aq_brand_ada` in prototypes/v11/aq-icons.js, plus the shadow).
class AdaBrandMark extends StatelessWidget {
  const AdaBrandMark({super.key, this.size = 28, this.semanticLabel});

  final double size;

  /// Null keeps it decorative, which is right beside text that already says
  /// "Aqademiq" or "Ada".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
}
