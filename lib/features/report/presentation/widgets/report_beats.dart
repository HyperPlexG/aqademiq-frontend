import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_mood.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/weekly_report.dart';
import '../../../../shared/icons/aq_icon.dart';
import '../../../../shared/mascot/ada_mascot.dart';
import '../../../../shared/widgets/ic.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../report_copy.dart';
import 'core_column.dart';

/// The beats of the weekly story, one widget per page.
///
/// Sized from the v11 frames (`core-*`), which are drawn at 1× on a 402pt
/// phone, so the numbers here are the design's own: an 11pt caps label, a
/// 28pt statement (34 for the shape of the week), 13pt captions, the 132pt
/// numeral and a 104pt core.
///
/// Each beat is one screenful and must never scroll: a page you can half-scroll
/// inside a horizontal pager fights the swipe. [BeatFrame] enforces that by
/// centring the content and letting it shrink rather than overflow.
abstract final class BeatSize {
  static const double label = 11;
  static const double shape = 34;
  static const double statement = 28;
  static const double body = 13;
  static const double numeral = 132;
  static const double coreWidth = 104;

  /// Seven 42pt bands and the rim, as `IceCore w={104} band={42}` draws it.
  static const double coreHeight = 306;
  static const double cube = 40;

  /// The cracked cube that marks one thaw.
  static const double thawCube = 30;
}

/// Common frame: the story's 22pt margins, vertical centring a little above the
/// middle (as every `core-*` frame sits), and a hard no-overflow rule.
class BeatFrame extends StatelessWidget {
  const BeatFrame({super.key, required this.children, this.crossAxisAlignment = CrossAxisAlignment.center});

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        // Never expected to scroll. It is here so a small phone or a large
        // text-scale setting degrades into a scroll instead of a hazard stripe.
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The small caps label above a statement (v11 `CoreCap`: 11/800, 0.14em).
class BeatLabel extends StatelessWidget {
  const BeatLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.sans(
          size: BeatSize.label,
          weight: FontWeight.w800,
          letterSpacing: AppText.em(0.14, BeatSize.label),
          color: context.colors.textDim,
        ),
      );
}

/// The one big sentence a beat exists to deliver.
class BeatStatement extends StatelessWidget {
  const BeatStatement(this.text, {super.key, this.quoted = false, this.size = BeatSize.statement});
  final String text;
  final bool quoted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final big = size >= BeatSize.shape;
    return Text(
      quoted ? '“$text”' : text,
      textAlign: TextAlign.center,
      style: AppText.sans(
        size: size,
        weight: FontWeight.w800,
        height: big ? 1.28 : 1.35,
        letterSpacing: big ? -0.6 : -0.4,
        color: context.colors.text,
      ),
    );
  }
}

class BeatBody extends StatelessWidget {
  const BeatBody(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.sans(size: BeatSize.body, weight: FontWeight.w500, height: 1.6, color: context.colors.textMed),
      );
}

/// The core with its day labels beside it — the same drawing on beats 1 and 3.
class _CoreWithLabels extends StatelessWidget {
  const _CoreWithLabels({required this.days, this.emphasise});

  final List<ReportDay> days;
  final int? emphasise;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoreDayLabels(days: days, height: BeatSize.coreHeight, emphasise: emphasise),
          const SizedBox(width: 9),
          CoreColumn(days: days, height: BeatSize.coreHeight, width: BeatSize.coreWidth),
        ],
      );
}

// ---------------------------------------------------------------------------
// Beat 1 — the core freezes in.
// ---------------------------------------------------------------------------

/// Not a spinner. The same column the story opens with, so arriving at beat 3
/// is continuous rather than a swap — and so the wait is the drilling, which is
/// the one place in this feature where making someone wait is the point.
class BeatDrilling extends StatelessWidget {
  const BeatDrilling({super.key, this.days = const []});

  final List<ReportDay> days;

  @override
  Widget build(BuildContext context) {
    // Before the data lands there are no days, so seven blanks stand in: the
    // tube is drawn empty and fills in place.
    final shown = days.isEmpty
        ? [for (var i = 0; i < 7; i++) ReportDay(date: DateTime.now(), weekday: i + 1, hasActivity: false)]
        : days;

    return BeatFrame(
      children: [
        _CoreWithLabels(days: shown),
        const SizedBox(height: 22),
        Text(
          ReportCopy.drilling,
          textAlign: TextAlign.center,
          style: AppText.sans(size: 15, letterSpacing: AppText.em(0.02, 15), color: context.colors.textDim),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 2 — the shape of the week.
// ---------------------------------------------------------------------------

class BeatShape extends StatelessWidget {
  const BeatShape({super.key, required this.shape});
  final WeekShape shape;

  @override
  Widget build(BuildContext context) => BeatFrame(
        children: [
          const BeatLabel(ReportCopy.shapeLabel),
          const SizedBox(height: 12),
          BeatStatement(ReportCopy.shape(shape), quoted: true, size: BeatSize.shape),
        ],
      );
}

// ---------------------------------------------------------------------------
// Beat 3 — the core itself. The screenshot.
// ---------------------------------------------------------------------------

class BeatCore extends StatelessWidget {
  const BeatCore({super.key, required this.report});
  final WeeklyReport report;

  /// The thin week's smaller core: seven 34pt bands and the rim.
  static const double _thinHeight = 250;

  @override
  Widget build(BuildContext context) {
    // A thin week, told in the same register (v11 `core-thin`): the shape's
    // sentence stays with the core, and the caption reaches for the smallest
    // true thing about the one day rather than explaining six open bands.
    final active = report.days.where((d) => d.hasActivity).toList();
    if (report.shape == WeekShape.single && active.isNotEmpty) {
      return BeatFrame(
        children: [
          BeatStatement(ReportCopy.shape(report.shape), quoted: true, size: 22),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoreDayLabels(days: report.days, height: _thinHeight, emphasise: active.first.weekday),
              const SizedBox(width: 9),
              CoreColumn(days: report.days, height: _thinHeight, width: 92),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: BeatBody(ReportCopy.smallestTrueThing(active.first)),
          ),
        ],
      );
    }

    // Name the first open day rather than explaining gaps in the abstract —
    // and say nothing at all when the week has none. `isGap` excludes days that
    // have not happened: Friday is not a gap on a Thursday.
    final firstGap = report.days.where((d) => d.isGap).toList();
    final caption = firstGap.isEmpty
        ? ReportCopy.coreCaption
        : '${ReportCopy.coreCaption} ${ReportCopy.gapCaption(weekdayName(firstGap.first.weekday))}';

    return BeatFrame(
      children: [
        _CoreWithLabels(days: report.days, emphasise: firstGap.isEmpty ? null : firstGap.first.weekday),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: BeatBody(caption),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 4 — one thing that happened.
// ---------------------------------------------------------------------------

class BeatMoment extends StatelessWidget {
  const BeatMoment({super.key, required this.moment, this.subjectName, this.subjectColor});

  final ReportMoment moment;
  final String? subjectName;
  final String? subjectColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dot = subjectColor == null ? colors.accent : hexColor(subjectColor!);

    return BeatFrame(
      children: [
        const BeatLabel(ReportCopy.momentTitle),
        const SizedBox(height: 12),
        BeatStatement(ReportCopy.moment(moment)),
        const SizedBox(height: 18),
        // The receipt: the task as it actually sits in the planner. A named
        // thing is what makes the beat non-aggregate.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 15, weight: FontWeight.w700, color: colors.text),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      ReportCopy.momentWhere(moment, subjectName),
                      style: AppText.sans(size: 12, weight: FontWeight.w500, color: colors.textMed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 5 — the one numeral.
// ---------------------------------------------------------------------------

/// Playfair, large, alone. Always a count of things that happened — never a
/// rate, percentage, score or change, and with nothing to divide it by.
class BeatNumeral extends StatelessWidget {
  const BeatNumeral({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BeatFrame(
      children: [
        Text(
          '$value',
          style: AppText.numeral(size: BeatSize.numeral, height: 0.85, letterSpacing: -4, color: colors.text),
        ),
        const SizedBox(height: 16),
        Text(
          ReportCopy.heroLabel,
          textAlign: TextAlign.center,
          style: AppText.sans(
            size: 13,
            weight: FontWeight.w800,
            letterSpacing: AppText.em(0.2, 13),
            color: colors.textDim,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 6 — where attention went.
// ---------------------------------------------------------------------------

/// One cube per subject in its own tint, sized and melted by share: the crisper
/// the cube, the more of the week it held.
///
/// A subject that got nothing this week is drawn as an unlabelled dashed slot —
/// visible in the distribution, never named in copy. A named list of subjects
/// you did not touch, under the heading "where attention went", is a list of
/// things you failed to do.
class BeatAttention extends StatelessWidget {
  const BeatAttention({super.key, required this.report, this.untouched = 0});

  final WeeklyReport report;

  /// How many of the student's subjects saw nothing this week.
  final int untouched;

  /// The cube's own box at the largest share, so every column lines up.
  static const double _slot = 64;

  static AdaTone _toneFor(Color c) => AdaTone(
        c,
        Color.lerp(c, Colors.white, 0.72)!,
        Color.lerp(c, Colors.black, 0.35)!,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // At most four cubes: the tail of a distribution is not what this beat is
    // for, and four columns are what a 320pt phone holds with their labels.
    final shown = report.subjects.take(4).toList();
    final top = shown.isEmpty ? 0.0 : shown.map((s) => s.share).reduce(math.max);
    final labelStyle = AppText.sans(
      size: 11,
      weight: FontWeight.w800,
      letterSpacing: AppText.em(0.04, 11),
      color: colors.text,
    );

    return BeatFrame(
      children: [
        const BeatLabel(ReportCopy.attentionTitle),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final s in shown)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: _slot,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AdaMascot(
                          size: 30 + s.share.clamp(0.0, 1.0) * 34,
                          tone: [_toneFor(s.colorHex == null ? colors.accent : hexColor(s.colorHex!))],
                          toneIndex: 0,
                          expr: AdaExpr.neutral,
                          // Relative, not absolute: the busiest subject of the
                          // week is always crisp, and the melt is capped, so a
                          // quiet week is not drawn as a row of puddles.
                          melt: top <= 0 ? 0 : ((1 - s.share / top) * 0.55).clamp(0.0, 0.55),
                          bubbles: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      // Null when the subject was deleted after the work
                      // happened: it keeps its cube and loses its name.
                      s.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < untouched.clamp(0, 2); i++)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: _slot,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: CustomPaint(
                          painter: _DashedSlotPainter(color: dark ? colors.textDim : const Color(0xFFD6D2CA)),
                          child: const SizedBox.square(dimension: 34),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    // Holds the label line so the open slot sits on the same
                    // baseline as its neighbours, and says nothing.
                    Text('–', style: labelStyle.copyWith(color: Colors.transparent)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        BeatBody(ReportCopy.attentionCaption(shown.isEmpty ? null : shown.first.name)),
      ],
    );
  }
}

class _DashedSlotPainter extends CustomPainter {
  const _DashedSlotPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
        const Radius.circular(10),
      ));
    const dash = 5.0;
    const space = 4.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0.0, m.length)), paint);
        d += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Beat 7 — when you thawed.
// ---------------------------------------------------------------------------

/// App freeze's thaws on the days they happened, one cracked cube per thaw,
/// stacked bottom-up — so the count is drawn, not written, and the report keeps
/// its one numeral. A day with none carries a small dot, not an empty box.
///
/// Thawing is how App freeze is meant to work, so nothing here grades it: the
/// sentence is the same for one thaw or ten. The screen only builds this beat
/// when App freeze is set up and the week holds at least one thaw (see
/// `report_thaws.dart`); otherwise it is absent.
class BeatThawed extends StatelessWidget {
  const BeatThawed({super.key, required this.days, required this.thaws});

  final List<ReportDay> days;

  /// Thaws per entry of [days], in the same order.
  final List<int> thaws;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// The tallest a stack may grow before it is drawn smaller. Two cubes fit the
  /// design's 70; a day with many thaws still stays on the page.
  static const double _maxStack = 166;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ice = dark ? AqIcon.iceOnDarkColor : AqIcon.iceColor;
    final most = thaws.isEmpty ? 0 : thaws.reduce(math.max);
    final stack = (most * (BeatSize.thawCube + 4) - 4).clamp(70.0, _maxStack);

    return BeatFrame(
      children: [
        const BeatLabel(ReportCopy.thawedTitle),
        const SizedBox(height: 12),
        const BeatStatement(ReportCopy.thawed),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 14),
          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(18)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: _ThawDay(
                    letter: _letters[(days[i].weekday - 1).clamp(0, 6)],
                    semantics: ReportCopy.thawedDay(weekdayName(days[i].weekday), i < thaws.length ? thaws[i] : 0),
                    count: i < thaws.length ? thaws[i] : 0,
                    stack: stack,
                    ice: ice,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const BeatBody(ReportCopy.thawedCaption),
      ],
    );
  }
}

class _ThawDay extends StatelessWidget {
  const _ThawDay({
    required this.letter,
    required this.semantics,
    required this.count,
    required this.stack,
    required this.ice,
  });

  final String letter;
  final String semantics;
  final int count;
  final double stack;
  final Color ice;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: stack,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: count == 0
                  ? Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: colors.border, shape: BoxShape.circle),
                    )
                  // Full size whenever the stack fits; a day with more thaws
                  // than the stack holds is drawn smaller, never cut off.
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // Stacked bottom-up, like ice settling.
                        verticalDirection: VerticalDirection.up,
                        children: [
                          for (var i = 0; i < count; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            Ic('cube_cracked', size: BeatSize.thawCube, color: ice),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            letter,
            style: AppText.sans(
              size: 11,
              weight: FontWeight.w800,
              letterSpacing: AppText.em(0.08, 11),
              color: count > 0 ? colors.text : colors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 8 — what the week gave back.
// ---------------------------------------------------------------------------

/// The recovery read, and the only beat that can read a hard week as recovery
/// rather than shortfall. It renders only when the lift points positive, which
/// the server enforces by returning nothing at all otherwise.
class BeatRecovery extends StatelessWidget {
  const BeatRecovery({super.key, required this.recovery});
  final ReportRecovery recovery;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Ada's expression is floored at neutral on the way in — she is never sad
    // *at* the student, so "going in" is drawn tired, not miserable.
    final beforeIdx = (recovery.beforeAvg.round() - 1).clamp(0, 4);
    final afterIdx = (recovery.afterAvg.round() - 1).clamp(0, 4);

    return BeatFrame(
      children: [
        const BeatLabel(ReportCopy.recoveryTitle),
        const SizedBox(height: 12),
        BeatStatement(ReportCopy.recovery(recovery)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(16)),
          // Scaled down rather than wrapped: the going-in/coming-out pair only
          // means anything read left-to-right on one line, and the labels are
          // long enough to overflow a 320pt phone (and any phone at a large
          // text scale) if they are allowed their natural width.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Face(label: ReportCopy.goingIn, toneIndex: beforeIdx, expr: AdaExpr.meh, melt: 0.45),
                const SizedBox(width: 20),
                Ic('forward', size: 20, color: colors.textDim),
                const SizedBox(width: 20),
                _Face(label: ReportCopy.comingOut, toneIndex: afterIdx, expr: AdaExpr.smile, melt: 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.label, required this.toneIndex, required this.expr, required this.melt});

  final String label;
  final int toneIndex;
  final AdaExpr expr;
  final double melt;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          AdaMascot(size: BeatSize.cube, toneIndex: toneIndex, expr: expr, melt: melt, bubbles: 2),
          const SizedBox(height: 7),
          Text(
            label,
            style: AppText.sans(
              size: 11,
              weight: FontWeight.w800,
              letterSpacing: AppText.em(0.1, 11),
              color: context.colors.textDim,
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// The quieter facts. Not one of the design's beats — a single page for the
// things §4 of the design lists as cards, so the work that measured them is not
// invisible, without giving any of them a beat of its own.
// ---------------------------------------------------------------------------

class BeatTexture extends StatelessWidget {
  const BeatTexture({super.key, required this.rows});

  /// (label, line) pairs, already filtered to the ones that have something true
  /// to say. A row with nothing to say is absent, never zeroed.
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BeatFrame(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, line) in rows) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BeatLabel(label),
                const SizedBox(height: 7),
                Text(line, style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.45, color: colors.text)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 9 — one small thing. The landing.
// ---------------------------------------------------------------------------

/// Sized so that refusing it would feel absurd, and refusable in one tap.
///
/// "Not this time" is a real option sitting at the same weight as sharing. A
/// landing with a single forward action is a landing that asks for something.
class BeatLanding extends StatelessWidget {
  const BeatLanding({
    super.key,
    required this.isEmptyWeek,
    required this.onKeep,
    required this.onShare,
    required this.onDismiss,
  });

  final bool isEmptyWeek;
  final VoidCallback onKeep;
  final VoidCallback onShare;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quiet = AppText.sans(size: 15, weight: FontWeight.w700, color: colors.textMed);
    return BeatFrame(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CoreAda: Ada reads. Never grades, never prescribes.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdaMascot(size: 28, expr: AdaExpr.smile, bubbles: 2),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEmptyWeek ? ReportCopy.closingEmpty : ReportCopy.closing,
                style: AppText.sans(size: 15, weight: FontWeight.w500, height: 1.6, color: colors.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.accent.withValues(alpha: 0.33), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(10)),
                child: Ic('wind_down', size: 20, color: colors.accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ReportCopy.suggestionTitle, style: AppText.sans(size: 17, weight: FontWeight.w800, color: colors.text)),
                    const SizedBox(height: 1),
                    Text(ReportCopy.suggestionSub, style: AppText.sans(size: 13, weight: FontWeight.w500, color: colors.textMed)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PrimaryButton(label: ReportCopy.keepIt, onPressed: onKeep),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onShare,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  // Nested in a Wrap, so it must size to its children rather
                  // than to the unbounded width it is offered.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Ic('share', size: 19, color: colors.textMed),
                    const SizedBox(width: 5),
                    Text(ReportCopy.shareLabel, style: quiet),
                  ],
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Text(ReportCopy.notThisTime, style: quiet),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// A bad season, not a bad week.
// ---------------------------------------------------------------------------

/// One quiet, dismissible line **outside** the story, in plain product voice
/// rather than the mascot's. It does not escalate, does not offer productivity
/// advice, and Ada never comments on it — a cartoon ice cube diagnosing a run
/// of hard weeks is out of its depth.
class SupportBanner extends StatelessWidget {
  const SupportBanner({super.key, required this.onView, required this.onDismiss});

  final VoidCallback onView;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      padding: const EdgeInsets.fromLTRB(12, 4, 2, 4),
      decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text.rich(
                TextSpan(
                  text: '${ReportCopy.supportBanner} ',
                  style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.55, color: colors.textMed),
                  children: [
                    TextSpan(
                      text: ReportCopy.supportAction,
                      style: AppText.sans(size: 13, weight: FontWeight.w800, height: 1.55, color: colors.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Ic('close', size: 21, color: colors.textDim),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// The mood tint of a day, exposed for the share card so it can deliberately
/// *not* use it. Kept here so the omission is visible in one place.
Color? moodTintOf(ReportDay day) => AppMood.tint(day.moodIndex);
