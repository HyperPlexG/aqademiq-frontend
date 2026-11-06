import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/icons/aq_icon.dart';

/// Ada's thinking loader (v11 `ThinkMark`): the five Tier 3 state marks in
/// turn, each with its own motion. Scattered thoughts gather (Distracted,
/// Creative), narrow (Focus), lock in (Deep Focus), settle (Relax).
///
/// One 4.5 s loop; each mark holds the stage for 0.9 s — it grows in from 55%,
/// stays, then swells to 120% as it fades. With reduced motion on nothing
/// moves and only Focus is drawn.
///
/// Time comes from a [Ticker] into a [ValueNotifier], so a frame repaints the
/// 22 px canvas and rebuilds nothing.
class ThinkMark extends StatefulWidget {
  const ThinkMark({super.key, this.size = 22, this.color});

  final double size;

  /// Defaults to the accent.
  final Color? color;

  @override
  State<ThinkMark> createState() => _ThinkMarkState();
}

class _ThinkMarkState extends State<ThinkMark> with SingleTickerProviderStateMixin {
  final _seconds = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) {
      _ticker.stop();
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final color = widget.color ?? context.colors.accent;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _ThinkPainter(seconds: _seconds, color: color, still: still),
      ),
    );
  }
}

class _ThinkPainter extends CustomPainter {
  _ThinkPainter({required this.seconds, required this.color, required this.still}) : super(repaint: seconds);

  final ValueNotifier<double> seconds;
  final Color color;
  final bool still;

  /// THINK_SEQ, in stage order.
  static const List<AqGlyph> _sequence = [
    AqIcons.stateDistracted,
    AqIcons.stateCreative,
    AqIcons.stateFocus,
    AqIcons.stateDeepFocus,
    AqIcons.stateRelax,
  ];

  /// THINK_BUBBLES: state_distracted split into its circles (cx, cy, r) so each
  /// drifts on its own.
  static const List<(double, double, double)> _bubbles = [
    (7.0, 16.0, 2.0),
    (13.0, 13.5, 1.25),
    (11.0, 8.5, 0.6),
    (17.0, 9.0, 1.25),
    (19.5, 4.25, 0.6),
  ];

  static const double _loop = 4.5;
  static const double _stagger = 0.9;
  static const Offset _origin = Offset(12, 12);

  static double _ease(double t) => Curves.easeInOut.transform(t.clamp(0.0, 1.0));

  /// A 0 → 1 → 0 swing over [period] seconds, eased each way.
  static double _swing(double t, double period) {
    final p = (t % period) / period;
    return p < 0.5 ? _ease(p / 0.5) : 1 - _ease((p - 0.5) / 0.5);
  }

  /// `aqThinkSlot`: (opacity, scale) for a slot [local] seconds into its run.
  static (double, double) _slot(double local) {
    if (local < 0) return (0.0, 0.55); // before its first turn (`backwards`)
    final q = (local % _loop) / _loop;
    if (q < 0.04) {
      final e = _ease(q / 0.04);
      return (e, 0.55 + 0.45 * e);
    }
    if (q < 0.20) return (1.0, 1.0);
    if (q < 0.24) {
      final e = _ease((q - 0.20) / 0.04);
      return (1 - e, 1 + 0.2 * e);
    }
    return (0.0, 1.2);
  }

  Paint _stroke(double opacity) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = AqGlyph.defaultStrokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color.withValues(alpha: color.a * opacity);

  Paint _fill(double opacity) => Paint()
    ..style = PaintingStyle.fill
    ..color = color.withValues(alpha: color.a * opacity);

  static void _about(Canvas canvas, void Function() transform) {
    canvas.translate(_origin.dx, _origin.dy);
    transform();
    canvas.translate(-_origin.dx, -_origin.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = size.shortestSide / AqGlyph.gridSize;
    canvas
      ..save()
      ..translate((size.width - AqGlyph.gridSize * unit) / 2, (size.height - AqGlyph.gridSize * unit) / 2)
      ..scale(unit);

    if (still) {
      _drawLayers(canvas, AqIcons.stateFocus, 0);
      canvas.restore();
      return;
    }

    final t = seconds.value;
    for (var i = 0; i < _sequence.length; i++) {
      final (opacity, scale) = _slot(t - i * _stagger);
      if (opacity <= 0.001) continue;
      canvas.save();
      _about(canvas, () => canvas.scale(scale));
      // Fade the mark as one piece, so overlapping strokes do not darken.
      final faded = opacity < 1;
      if (faded) {
        canvas.saveLayer(
          const Rect.fromLTWH(-6, -6, 36, 36),
          Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
        );
      }
      _drawLayers(canvas, _sequence[i], t);
      if (faded) canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  /// One mark with its own motion (THINK_ANIM) at [t] seconds.
  void _drawLayers(Canvas canvas, AqGlyph glyph, double t) {
    final line = _stroke(1);
    switch (glyph.name) {
      case 'state_distracted':
        for (var k = 0; k < _bubbles.length; k++) {
          final (cx, cy, r) = _bubbles[k];
          final e = still ? 0.0 : _swing(t + k * 0.18, 0.9); // aqDrift, staggered
          canvas.drawCircle(Offset(cx + 1.2 * e, cy - 1.6 * e), r, _stroke(0.45 + 0.55 * e));
        }
      case 'state_creative':
        canvas.save();
        _about(canvas, () => canvas.rotate(2 * math.pi * (t % 1.6) / 1.6)); // aqSpin 1.6s
        for (final layer in glyph.layers) {
          canvas.drawPath(layer.shape, line);
        }
        canvas.restore();
      default:
        for (final layer in glyph.layers) {
          canvas.save();
          switch ('${glyph.name}.${layer.id}') {
            case 'state_focus.outer':
              _about(canvas, () => canvas.rotate(2 * math.pi * (t % 1.4) / 1.4));
            case 'state_focus.inner':
              _about(canvas, () => canvas.rotate(-2 * math.pi * (t % 1.1) / 1.1));
            case 'state_deep_focus.core':
              _about(canvas, () => canvas.scale(0.7 + 0.3 * _swing(t, 0.9))); // aqPulse
            case 'state_relax.wave1':
              canvas.translate(0, -1 + 2 * _swing(t, 1)); // aqBob
            case 'state_relax.wave2':
              canvas.translate(0, -1 + 2 * _swing(t + 0.5, 1));
          }
          final shape = layer.shape;
          if (layer.paint) canvas.drawPath(shape, _fill(1));
          canvas
            ..drawPath(shape, line)
            ..restore();
        }
    }
  }

  @override
  bool shouldRepaint(_ThinkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.still != still || oldDelegate.seconds != seconds;
}
