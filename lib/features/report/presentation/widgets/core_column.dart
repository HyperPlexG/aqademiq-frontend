import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_mood.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/weekly_report.dart';

/// The core: seven days drilled out as a single translucent column.
///
/// An ice core is a record of a season, and nobody grades one — you read layers
/// off it. That posture is the whole reason this is a column of bands and not
/// seven bars on an axis: bars invite comparison against each other and against
/// whatever the tallest one is, and a column of ice does not have a tallest.
///
/// Three things the drawing must get right, all of them about honesty rather
/// than looks:
///
///  * **An empty day is an empty band, never a puddle.** A day with nothing
///    logged gets a dashed outline and no fill. Tinting it with the low end of
///    the ramp would draw "nothing logged" as "a bad day", which is a claim the
///    data does not support and the student cannot correct.
///  * **A day that happened but carries no mood is drawn solid and untinted.**
///    Work with no check-in is not the same as no work, and it is not the same
///    as a mood either.
///  * **Nothing here encodes volume.** Every band is the same height. Minutes
///    are reported in words elsewhere; a band that grew with effort is a bar
///    chart wearing a metaphor, and it would make a thin week look thin.
class CoreColumn extends StatefulWidget {
  const CoreColumn({
    super.key,
    required this.days,
    this.height = 300,
    this.width = 74,
  });

  final List<ReportDay> days;
  final double height;
  final double width;

  @override
  State<CoreColumn> createState() => _CoreColumnState();
}

class _CoreColumnState extends State<CoreColumn> with SingleTickerProviderStateMixin {
  /// 1.2s: long enough to read as a thing being drilled rather than a screen
  /// loading, short enough that nobody waits through it twice.
  static const _duration = Duration(milliseconds: 1250);

  late final AnimationController _c = AnimationController(vsync: this, duration: _duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Eased 0-1 progress for the band at [i], staggered so the layers settle
  /// top-down the way sediment does.
  double _bandT(int i, double t) {
    const spread = 0.55;
    final start = 0.22 + (i / 7) * spread;
    final raw = ((t - start) / 0.3).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final n = widget.days.length;
    const gap = 2.0;
    final bandH = n == 0 ? widget.height : (widget.height - gap * (n - 1)) / n;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        // The column forms first, then the layers arrive inside it.
        final columnT = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0));

        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Opacity(
            opacity: columnT,
            child: Transform.scale(
              scaleY: 0.72 + 0.28 * columnT,
              alignment: Alignment.topCenter,
              child: Stack(
                children: [
                  // The ice itself: a faint body that exists even where no band
                  // is filled, so an empty week still reads as a core that was
                  // drilled rather than a screen that failed to load.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.width / 2.6),
                        color: colors.accent.withValues(alpha: 0.05),
                        border: Border.all(color: colors.accent.withValues(alpha: 0.14)),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.width / 2.6),
                      child: Column(
                        children: [
                          for (var i = 0; i < n; i++) ...[
                            if (i > 0) const SizedBox(height: gap),
                            _Band(day: widget.days[i], height: bandH, t: _bandT(i, t)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Specular highlight — a single soft vertical sheen down the
                  // left of the column. This is what stops the stack of bands
                  // reading as a flat list and starts it reading as a cylinder.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.width / 2.6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.16 * columnT),
                                Colors.white.withValues(alpha: 0.02 * columnT),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.07 * columnT),
                              ],
                              stops: const [0, 0.22, 0.62, 1],
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
      },
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.day, required this.height, required this.t});

  final ReportDay day;
  final double height;

  /// 0-1 entrance progress for this band alone.
  final double t;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = AppMood.tint(day.moodIndex);

    // An empty band never fills. It is outlined so the gap is visibly a gap —
    // a day the core has no layer for — rather than a day drawn as low.
    if (!day.hasActivity) {
      return Expanded(
        child: Opacity(
          opacity: t,
          child: CustomPaint(
            painter: _DashedBandPainter(color: colors.textDim.withValues(alpha: 0.55)),
            child: const SizedBox.expand(),
          ),
        ),
      );
    }

    // A day that happened with no mood logged: solid, and deliberately neutral.
    final base = tint ?? colors.accent.withValues(alpha: 0.30);

    return Expanded(
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -6 * (1 - t)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  base.withValues(alpha: (base.a * 0.92).clamp(0.0, 1.0)),
                  base,
                  base.withValues(alpha: (base.a * 0.74).clamp(0.0, 1.0)),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded outline for a day with nothing logged.
class _DashedBandPainter extends CustomPainter {
  const _DashedBandPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;

    final rect = Rect.fromLTWH(2, 1, size.width - 4, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    final path = Path()..addRRect(rrect);

    const dash = 4.0;
    const space = 3.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBandPainter old) => old.color != color;
}

/// MON…SUN down the left of the core, aligned to the bands beside them.
class CoreDayLabels extends StatelessWidget {
  const CoreDayLabels({super.key, required this.days, required this.height});

  static const _letters = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  final List<ReportDay> days;
  final double height;

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
                    size: 8,
                    weight: FontWeight.w800,
                    letterSpacing: AppText.em(0.12, 8),
                    // The label for an empty day dims with its band, so the
                    // gap reads as one thing rather than a labelled void.
                    color: days[i].hasActivity ? colors.textMed : colors.textDim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
