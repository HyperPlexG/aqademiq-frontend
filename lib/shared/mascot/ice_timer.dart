import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'ada_mascot.dart';

/// The Focus "Ice melt" timer (prototype `IceTimer`): a progress ring around the
/// Ada cube, which melts as [progress] (0..1) advances.
///
/// [frost] is the paused session (`fc-paused`): Ada stops where she is and turns
/// to frost, the arc goes cyan, and an inset frost glow shimmers round the ring.
/// She keeps the melt she had — a freeze holds time, it does not give it back.
class IceTimer extends StatefulWidget {
  const IceTimer({
    super.key,
    this.progress = 0,
    this.size = 150,
    this.expr = AdaExpr.happy,
    this.frost = false,
  });

  final double progress;
  final double size;
  final AdaExpr expr;
  final bool frost;

  @override
  State<IceTimer> createState() => _IceTimerState();
}

class _IceTimerState extends State<IceTimer> with SingleTickerProviderStateMixin {
  // One loop, two jobs. Running, it is a slow "breathing" so the cube is
  // visibly alive (the melt itself advances over the whole session, too subtle
  // second-to-second). Frozen, the cube holds still (FOC-4) and the same loop
  // drives the frost shimmer instead — the prototype's `aqShimmer 2.2s`.
  late final AnimationController _pulse = AnimationController(vsync: this);

  static const _breath = Duration(milliseconds: 2200);
  static const _shimmer = Duration(milliseconds: 1100); // reversing, so 2.2s a cycle

  void _loop() => unawaited(_pulse.repeat(reverse: true, period: widget.frost ? _shimmer : _breath));

  @override
  void initState() {
    super.initState();
    _loop();
  }

  @override
  void didUpdateWidget(covariant IceTimer old) {
    super.didUpdateWidget(old);
    if (old.frost != widget.frost) _loop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = widget.progress.clamp(0.0, 1.0);
    // Smoothly interpolate the arc + melt between per-second ticks (the
    // prototype's `transition: stroke-dashoffset 0.9s linear`) so the cube
    // visibly melts while running rather than snapping each second (FOC-4).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: p),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, _) => SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: _RingPainter(
                progress: value,
                track: colors.hilite,
                arc: widget.frost ? const Color(0xFF9FD6EF) : colors.accent,
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = widget.frost ? 0.0 : Curves.easeInOut.transform(_pulse.value);
                return Transform.scale(
                  scale: 1.0 + 0.035 * t,
                  child: Opacity(opacity: 0.9 + 0.1 * t, child: child),
                );
              },
              child: AdaMascot(
                size: widget.size * 0.6,
                melt: value,
                expr: widget.expr,
                frozen: widget.frost,
              ),
            ),
            if (widget.frost)
              IgnorePointer(
                child: FadeTransition(
                  // 0.35 → 0.7 → 0.35, as `@keyframes aqShimmer`.
                  opacity: _pulse.drive(Tween(begin: 0.35, end: 0.7)),
                  child: CustomPaint(
                    size: Size.square(widget.size),
                    painter: const _FrostGlowPainter(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The prototype's `box-shadow: inset 0 0 20px rgba(159,214,239,0.65)` on a
/// circle: frost creeping in from the rim, gone well before the centre.
class _FrostGlowPainter extends CustomPainter {
  const _FrostGlowPainter();

  static const _frost = Color(0xFF9FD6EF);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = size.center(Offset.zero);
    // A 20px blur reaches about 20px in; as a fraction of the radius so the
    // glow keeps its depth at whatever size the timer is drawn.
    final inner = (1 - 20 / r).clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [_frost.withValues(alpha: 0), _frost.withValues(alpha: 0.22), _frost.withValues(alpha: 0.65)],
          stops: [inner, inner + (1 - inner) * 0.6, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_FrostGlowPainter old) => false;
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.arc});

  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final r = (size.width - stroke) / 2 - 1;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress > 0.001) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.arc != arc;
}
