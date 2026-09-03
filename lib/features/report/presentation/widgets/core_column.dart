import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_mood.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/weekly_report.dart';

/// The core: seven days drilled out as one translucent column.
///
/// An ice core is a record of a season, and nobody grades one — you read layers
/// off it. That posture is the whole reason this is a column of bands and not
/// seven bars on an axis: bars invite comparison against each other and against
/// whatever the tallest one is, and a column of ice does not have a tallest.
///
/// Three things the drawing must get right, all of them about honesty rather
/// than looks:
///
///  * **An empty day is an open band, never a puddle.** A day with nothing
///    logged gets a dashed outline and no fill. Tinting it with the pale end of
///    the ramp would draw "nothing logged" as "a bad day", which is a claim the
///    data does not support and the student cannot correct.
///  * **A day that happened but carries no mood is drawn solid and untinted.**
///    Work with no check-in is not the same as no work, and it is not a mood
///    either. Three states, and collapsing the middle one is the single easiest
///    way for this feature to say something false about someone.
///  * **Nothing here encodes volume.** Every band is the same height. Minutes
///    are reported in words elsewhere; a band that grew with effort is a bar
///    chart wearing a metaphor, and it would make a thin week look thin.
class CoreColumn extends StatefulWidget {
  const CoreColumn({
    super.key,
    required this.days,
    this.height = 340,
    this.width = 128,
    this.animate = true,
    this.showBubbles = true,
  });

  /// Sizes are in logical pixels against a ~390pt-wide phone, not the 2× of the
  /// design mocks — the column has to leave room for a caption under it and the
  /// story's own chrome above it on a 6.1" screen.
  const CoreColumn.mini({
    super.key,
    required this.days,
    this.height = 108,
    this.width = 46,
    this.animate = false,
    this.showBubbles = true,
  });

  final List<ReportDay> days;
  final double height;
  final double width;

  /// The freeze-in. Off for the entry-card thumbnail, which must not animate
  /// every time the Stats tab rebuilds.
  final bool animate;
  final bool showBubbles;

  @override
  State<CoreColumn> createState() => _CoreColumnState();
}

class _CoreColumnState extends State<CoreColumn> with SingleTickerProviderStateMixin {
  /// Long enough to read as a thing being drilled rather than a screen loading,
  /// short enough that nobody waits through it twice.
  static const _duration = Duration(milliseconds: 1250);

  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      final c = AnimationController(vsync: this, duration: _duration);
      _c = c;
      unawaited(c.forward());
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  /// Eased 0-1 progress for the band at [i], staggered so the layers settle
  /// top-down the way sediment does.
  double _bandT(int i, double t) {
    const spread = 0.55;
    final start = 0.22 + (i / 7) * spread;
    return Curves.easeOutCubic.transform(((t - start) / 0.3).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return _build(context, 1);
    return AnimatedBuilder(animation: c, builder: (context, _) => _build(context, c.value));
  }

  Widget _build(BuildContext context, double t) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final n = widget.days.length;
    final radius = widget.width * 0.42;

    // The column forms first, then the layers arrive inside it.
    final columnT = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));

    // The glass: a pale tube in dark mode, a whisper of lilac in light. It has
    // to be visible even where no band is filled, so an empty week still reads
    // as a core that was drilled rather than a screen that failed to load.
    final glassBody = dark ? Colors.white.withValues(alpha: 0.10) : colors.accent.withValues(alpha: 0.045);
    final glassEdge = dark ? Colors.white.withValues(alpha: 0.72) : colors.accent.withValues(alpha: 0.20);

    final gap = widget.width < 70 ? 3.0 : 6.0;
    final inset = widget.width < 70 ? 3.0 : 6.0;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Opacity(
        opacity: columnT,
        child: Transform.scale(
          scaleY: 0.78 + 0.22 * columnT,
          alignment: Alignment.topCenter,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The tube.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    color: glassBody,
                    border: Border.all(color: glassEdge, width: widget.width < 70 ? 1 : 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: dark ? 0.22 : 0.14),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // The rim: the ellipse that makes it a drilled cylinder rather
              // than a rounded rectangle. It is the whole read of the object.
              Positioned(
                left: -1,
                right: -1,
                top: -widget.width * 0.055,
                height: widget.width * 0.16,
                child: CustomPaint(painter: _RimPainter(color: glassEdge, fill: glassBody)),
              ),
              // The layers.
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset, vertical: inset + 1),
                  child: Column(
                    children: [
                      for (var i = 0; i < n; i++) ...[
                        if (i > 0) SizedBox(height: gap),
                        _Band(
                          day: widget.days[i],
                          t: _bandT(i, t),
                          bubbles: widget.showBubbles && widget.width >= 70,
                          radius: widget.width < 70 ? 5 : 9,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Specular streak — a single soft sheen down the left third. This
              // is what stops the stack of bands reading as a flat list.
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.02 * columnT),
                            Colors.white.withValues(alpha: (dark ? 0.30 : 0.55) * columnT),
                            Colors.white.withValues(alpha: 0.03 * columnT),
                            Colors.transparent,
                            Colors.black.withValues(alpha: (dark ? 0.16 : 0.05) * columnT),
                          ],
                          stops: const [0.04, 0.13, 0.26, 0.66, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.day, required this.t, required this.bubbles, required this.radius});

  final ReportDay day;

  /// 0-1 entrance progress for this band alone.
  final double t;
  final bool bubbles;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = AppMood.tint(day.moodIndex);

    // An open band never fills. It is outlined so the gap is visibly a gap — a
    // day the core has no layer for — rather than a day drawn as a pale mood.
    if (!day.hasActivity) {
      return Expanded(
        child: Opacity(
          opacity: t,
          child: CustomPaint(
            painter: _DashedBandPainter(
              color: dark ? Colors.white.withValues(alpha: 0.42) : colors.textDim,
              radius: radius,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    // A day that happened with no mood logged: solid, and deliberately neutral.
    final base = tint ?? colors.accent.withValues(alpha: dark ? 0.34 : 0.26);
    final fill = dark ? base.withValues(alpha: (base.a * 0.62).clamp(0.0, 1.0)) : base.withValues(alpha: (base.a * 0.34).clamp(0.0, 1.0));

    return Expanded(
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -8 * (1 - t)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: fill,
              border: Border.all(color: base.withValues(alpha: (base.a * 0.85).clamp(0.0, 1.0)), width: 1.2),
            ),
            child: bubbles
                ? Stack(
                    children: [
                      // Two trapped bubbles. Purely decorative, and the reason
                      // the bands read as ice rather than as progress bars.
                      Positioned(left: 8, top: 6, child: _Bubble(size: 4.5, color: Colors.white.withValues(alpha: dark ? 0.85 : 0.95))),
                      Positioned(left: 14, top: 17, child: _Bubble(size: 2.5, color: Colors.white.withValues(alpha: dark ? 0.55 : 0.7))),
                    ],
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// The elliptical rim at the top of the tube.
class _RimPainter extends CustomPainter {
  const _RimPainter({required this.color, required this.fill});
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas
      ..drawOval(rect, Paint()..color = fill)
      ..drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color,
      )
      // A highlight on the near lip, so the ellipse reads as an opening.
      ..drawArc(
        rect.deflate(1.5),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55),
      );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.color != color || old.fill != fill;
}

/// A dashed rounded outline for a day with nothing logged.
class _DashedBandPainter extends CustomPainter {
  const _DashedBandPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 5.0;
    const space = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBandPainter old) => old.color != color || old.radius != radius;
}

/// MON…SUN down the left of the core, aligned to the bands beside them.
class CoreDayLabels extends StatelessWidget {
  const CoreDayLabels({super.key, required this.days, required this.height, this.emphasise});

  static const _letters = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  final List<ReportDay> days;
  final double height;

  /// Weekday (1-7) to draw at full strength — the day a caption is talking
  /// about. Everything else stays quiet.
  final int? emphasise;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _letters[i % 7],
                  style: AppText.sans(
                    size: 9.5,
                    weight: FontWeight.w800,
                    letterSpacing: AppText.em(0.1, 9.5),
                    // The label for an open day dims with its band, so a gap
                    // reads as one thing rather than a labelled void.
                    color: emphasise == days[i].weekday
                        ? colors.text
                        : (days[i].hasActivity ? colors.textMed : colors.textDim),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
