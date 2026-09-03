import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_mood.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/hex_color.dart';
import '../../../../data/models/weekly_report.dart';
import '../../../../shared/mascot/ada_mascot.dart';
import '../../report_copy.dart';
import 'core_column.dart';

/// The beats of the weekly story, one widget per page.
///
/// All of these are laid out for a real phone — roughly 390pt wide and 700pt of
/// usable height once the story's own chrome is taken off the top. The design
/// mocks are 2× renders, so every size here is about half of what the mock
/// measures; taken literally the numeral alone would be 250pt tall and the core
/// would not fit on a 6.1" screen with its caption.
///
/// Each beat is one screenful and must never scroll: a page you can half-scroll
/// inside a horizontal pager fights the swipe. [BeatFrame] enforces that by
/// centring the content and letting it shrink rather than overflow.
///
/// Sizes worth not "tidying":
///  * `_statement` at 27 is the largest text that keeps "A quiet start, then
///    days that held." to three lines at 390pt. At 30 it takes four and the
///    beat stops reading as one held sentence.
///  * The numeral at 128 is the one place a big number is the whole point.
abstract final class BeatSize {
  static const double label = 9.5;
  static const double statement = 27;
  static const double body = 13.5;
  static const double numeral = 128;
  static const double coreWidth = 128;
  static const double coreHeight = 330;
  static const double cube = 44;
}

/// Common frame: safe padding, vertical centring, and a hard no-overflow rule.
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
            padding: const EdgeInsets.symmetric(horizontal: 26),
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

/// The small caps label above a statement.
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
          letterSpacing: AppText.em(0.16, BeatSize.label),
          color: context.colors.textMed,
        ),
      );
}

/// The one big sentence a beat exists to deliver.
class BeatStatement extends StatelessWidget {
  const BeatStatement(this.text, {super.key, this.quoted = false});
  final String text;
  final bool quoted;

  @override
  Widget build(BuildContext context) => Text(
        quoted ? '“$text”' : text,
        textAlign: TextAlign.center,
        style: AppText.sans(
          size: BeatSize.statement,
          weight: FontWeight.w800,
          height: 1.22,
          letterSpacing: -0.6,
          color: context.colors.text,
        ),
      );
}

class BeatBody extends StatelessWidget {
  const BeatBody(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.sans(size: BeatSize.body, height: 1.5, color: context.colors.textMed),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreDayLabels(days: shown, height: BeatSize.coreHeight),
            const SizedBox(width: 12),
            CoreColumn(days: shown, height: BeatSize.coreHeight),
          ],
        ),
        const SizedBox(height: 30),
        const BeatBody(ReportCopy.drilling),
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
          const SizedBox(height: 22),
          BeatStatement(ReportCopy.shape(shape), quoted: true),
        ],
      );
}

// ---------------------------------------------------------------------------
// Beat 3 — the core itself. The screenshot.
// ---------------------------------------------------------------------------

class BeatCore extends StatelessWidget {
  const BeatCore({super.key, required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    // Name the first open day rather than explaining gaps in the abstract —
    // and say nothing at all when the week has none.
    final firstGap = report.days.where((d) => !d.hasActivity).toList();
    final caption = firstGap.isEmpty
        ? ReportCopy.coreCaption
        : '${ReportCopy.coreCaption} ${ReportCopy.gapCaption(weekdayName(firstGap.first.weekday))}';

    return BeatFrame(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoreDayLabels(
              days: report.days,
              height: BeatSize.coreHeight,
              emphasise: firstGap.isEmpty ? null : firstGap.first.weekday,
            ),
            const SizedBox(width: 12),
            CoreColumn(days: report.days, height: BeatSize.coreHeight),
          ],
        ),
        const SizedBox(height: 26),
        BeatBody(caption),
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
        const SizedBox(height: 20),
        BeatStatement(ReportCopy.moment(moment)),
        const SizedBox(height: 26),
        // The receipt: the task as it actually sits in the planner. A named
        // thing is what makes the beat non-aggregate.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
          decoration: BoxDecoration(
            color: colors.hilite,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 14.5, weight: FontWeight.w800, color: colors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ReportCopy.momentWhere(moment, subjectName),
                      style: AppText.sans(size: 11.5, color: colors.textMed),
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
          style: AppText.numeral(size: BeatSize.numeral, weight: FontWeight.w500, color: colors.text),
        ),
        const SizedBox(height: 14),
        Text(
          ReportCopy.heroLabel,
          style: AppText.sans(
            size: 11,
            weight: FontWeight.w800,
            letterSpacing: AppText.em(0.2, 11),
            color: colors.textMed,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 6 — where attention went.
// ---------------------------------------------------------------------------

/// One cube per subject, melted by share: the crisper the cube, the more of the
/// week it held.
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

  static AdaTone _toneFor(Color c) => AdaTone(
        c,
        Color.lerp(c, Colors.white, 0.72)!,
        Color.lerp(c, Colors.black, 0.35)!,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // At most four cubes: five 44pt cubes with labels do not fit 390pt, and the
    // tail of a distribution is not what this beat is for.
    final shown = report.subjects.take(4).toList();
    final top = shown.isEmpty ? 0.0 : shown.first.share;

    return BeatFrame(
      children: [
        const BeatLabel(ReportCopy.attentionTitle),
        const SizedBox(height: 30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 18,
          runSpacing: 16,
          children: [
            for (final s in shown)
              SizedBox(
                width: 74,
                child: Column(
                  children: [
                    AdaMascot(
                      size: BeatSize.cube,
                      tone: [_toneFor(s.colorHex == null ? colors.accent : hexColor(s.colorHex!))],
                      toneIndex: 0,
                      expr: AdaExpr.neutral,
                      // Relative, not absolute: the busiest subject of the week
                      // is always crisp, so a quiet week is not drawn as a row
                      // of puddles.
                      melt: top <= 0 ? 0 : ((1 - s.share / top) * 0.55).clamp(0.0, 0.55),
                      bubbles: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      // Null when the subject was deleted after the work
                      // happened: it keeps its cube and loses its name.
                      s.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 11, weight: FontWeight.w800, color: colors.text),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < untouched.clamp(0, 2); i++)
              SizedBox(
                width: 74,
                child: Column(
                  children: [
                    CustomPaint(
                      painter: _DashedSlotPainter(color: colors.textDim),
                      child: const SizedBox.square(dimension: BeatSize.cube),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 13),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 30),
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
      ..strokeWidth = 1.2
      ..color = color;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 4, size.width - 4, size.height - 8),
        const Radius.circular(12),
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
// Beat 7 — what the week gave back.
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
        const SizedBox(height: 20),
        BeatStatement(ReportCopy.recovery(recovery)),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(color: colors.hilite, borderRadius: BorderRadius.circular(AppRadius.card)),
          // Scaled down rather than wrapped: the going-in/coming-out pair only
          // means anything read left-to-right on one line, and the labels are
          // long enough to overflow a 320pt phone (and any phone at a large
          // text scale) if they are allowed their natural width.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                _Face(label: ReportCopy.goingIn, toneIndex: beforeIdx, expr: AdaExpr.meh, melt: 0.45),
                const SizedBox(width: 20),
                Icon(Icons.arrow_forward, size: 18, color: colors.textMed),
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
          AdaMascot(size: 50, toneIndex: toneIndex, expr: expr, melt: melt, bubbles: 2),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppText.sans(
              size: 9.5,
              weight: FontWeight.w800,
              letterSpacing: AppText.em(0.14, 9.5),
              color: context.colors.textMed,
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// The quieter facts. Not one of the eight beats — a single page for the things
// §4 of the design lists as cards, so the work that measured them is not
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
            decoration: BoxDecoration(color: colors.hilite, borderRadius: BorderRadius.circular(AppRadius.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BeatLabel(label),
                const SizedBox(height: 7),
                Text(line, style: AppText.sans(size: 13.5, height: 1.35, color: colors.text)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Beat 8 — one small thing. The landing.
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
    return BeatFrame(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdaMascot(size: 34, expr: AdaExpr.smile, sparkles: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isEmptyWeek ? ReportCopy.closingEmpty : ReportCopy.closing,
                style: AppText.sans(size: 15, height: 1.45, color: colors.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.nightlight_round, size: 17, color: colors.accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ReportCopy.suggestionTitle, style: AppText.sans(size: 14.5, weight: FontWeight.w800, color: colors.text)),
                    const SizedBox(height: 2),
                    Text(ReportCopy.suggestionSub, style: AppText.sans(size: 11.5, color: colors.textMed)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.ink,
              foregroundColor: colors.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            onPressed: onKeep,
            child: Text(ReportCopy.keepIt, style: AppText.sans(size: 15, weight: FontWeight.w800, color: colors.bg)),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 22,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onShare,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  // Nested in a Row, so it must size to its children rather
                  // than to the unbounded width it is offered.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ios_share, size: 15, color: colors.text),
                    const SizedBox(width: 7),
                    Text(ReportCopy.shareLabel, style: AppText.sans(size: 13.5, weight: FontWeight.w700, color: colors.text)),
                  ],
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Text(ReportCopy.notThisTime, style: AppText.sans(size: 13.5, weight: FontWeight.w700, color: colors.textMed)),
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
      decoration: BoxDecoration(color: colors.hilite, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${ReportCopy.supportBanner} ',
                style: AppText.sans(size: 12.5, height: 1.4, color: colors.text),
                children: [
                  TextSpan(
                    text: ReportCopy.supportAction,
                    style: AppText.sans(size: 12.5, weight: FontWeight.w800, color: colors.text),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 16, color: colors.textMed),
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
