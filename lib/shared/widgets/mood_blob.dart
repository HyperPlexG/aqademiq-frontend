import 'package:flutter/widgets.dart';

import '../mascot/ada_mascot.dart';

/// The MOODS scale (0 Rough … 4 Great), label + nominal color (prototype MOODS).
class MoodScale {
  static const List<String> labels = ['Rough', 'Tired', 'OK', 'Good', 'Great'];

  /// Each mood's colour (v11 `MOODS`) — the border tone of its cube.
  static const List<Color> colors = [
    Color(0xFFA79FC4),
    Color(0xFF9286D2),
    Color(0xFF7D70D9),
    Color(0xFF6A5CE4),
    Color(0xFF5A44F1),
  ];
  static const List<AdaExpr> _expr = [
    AdaExpr.sad,
    AdaExpr.meh,
    AdaExpr.neutral,
    AdaExpr.smile,
    AdaExpr.happy,
  ];
  static const List<int> _bubbles = [0, 1, 1, 2, 3];
}

/// Per-day mood face used in week strips and check-ins (prototype `MoodBlob`).
/// Worse moods render smaller and more melted; idx 4 gets cheeks + sparkles,
/// idx 1 a sweat drop.
class MoodBlob extends StatelessWidget {
  const MoodBlob({super.key, this.idx = 2, this.size = 80});

  final int idx;
  final double size;

  @override
  Widget build(BuildContext context) {
    final i = idx.clamp(0, 4);
    final scale = 0.72 + i * 0.07;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: AdaMascot(
          size: size * scale,
          toneIndex: i,
          melt: (4 - i) / 4,
          expr: MoodScale._expr[i],
          bubbles: MoodScale._bubbles[i],
          cheeks: i == 4,
          sparkles: i == 4,
          sweat: i == 1,
        ),
      ),
    );
  }
}
