import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/weekly_report.dart';
import '../../../shared/icons/aq_icon.dart';
import '../../../shared/mascot/ada_mascot.dart';
import '../../../shared/widgets/circle_back_button.dart';
import '../../../shared/widgets/ic.dart';
import '../../../shared/widgets/primary_button.dart';
import '../report_copy.dart';

/// "Share the shape" — the activity shape of the week, and nothing else.
///
/// **Mood never leaves in a picture.** Mood is health data. Nothing exported
/// here may encode a mood value, tint, word, or anything derived from one,
/// including an archetype computed from mood. So the preview is built from a
/// copy of the week with every `moodIndex` stripped to null: the bands keep
/// their filled-or-open state — which is activity — and lose their colour.
///
/// Stripping the data rather than the drawing is deliberate. A share card that
/// merely *chose* not to paint the tint would still be one styling change away
/// from leaking it; one built from data that no longer contains a mood cannot
/// leak what it does not have.
Future<void> showShareShapeSheet(BuildContext context, WeeklyReport report) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => _ShareShapeScreen(report: report)),
  );
}

/// The week with mood removed. Activity shape survives; feeling does not.
WeeklyReport shapeOnly(WeeklyReport r) => WeeklyReport(
      weekStart: r.weekStart,
      weekEnd: r.weekEnd,
      shape: r.shape,
      activeDays: r.activeDays,
      elapsedDays: r.elapsedDays,
      daysOnBoard: r.daysOnBoard,
      days: [
        for (final d in r.days)
          ReportDay(
            date: d.date,
            weekday: d.weekday,
            hasActivity: d.hasActivity,
            // Preserved: a day that has not happened must not become an open
            // band on a card someone sends to their friends.
            isFuture: d.isFuture,
            tasksCompleted: d.tasksCompleted,
            focusMinutes: d.focusMinutes,
            focusSessions: d.focusSessions,
          ),
      ],
    );

/// v11 `core-share`: the story card previewed whole, one primary destination.
///
/// "Share to your story" sends the picture alone — a story wants an image, not
/// a caption. "More" sends the same picture with a line of text through the
/// same system sheet, which on iOS also offers Save Image. There is no separate
/// Save image button: saving straight to the photo library would need a
/// gallery plugin the app does not carry.
///
/// The picture is the card on screen, rendered at 3× (1080 × 1920). If it
/// cannot be drawn, the text goes alone rather than the tap doing nothing.
class _ShareShapeScreen extends StatefulWidget {
  const _ShareShapeScreen({required this.report});

  final WeeklyReport report;

  @override
  State<_ShareShapeScreen> createState() => _ShareShapeScreenState();
}

class _ShareShapeScreenState extends State<_ShareShapeScreen> {
  /// The card's own boundary, so the export is the card and nothing around it
  /// — not the preview's rounded clip, not its shadow.
  final _card = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stripped = shapeOnly(widget.report);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleBackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ReportCopy.shareLabel,
                      style: AppText.sans(size: 20, weight: FontWeight.w800, color: colors.text),
                    ),
                  ),
                ],
              ),
              // The card as it will be sent, as large as the page allows.
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: StoryCard.width * 0.78),
                      child: AspectRatio(
                        aspectRatio: StoryCard.width / StoryCard.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(color: Color(0x5713102A), blurRadius: 50, offset: Offset(0, 18)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: FittedBox(
                              child: RepaintBoundary(key: _card, child: StoryCard(report: stripped)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ic('shield', size: 19, color: colors.textMed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ReportCopy.sharePrivacy,
                      style: AppText.sans(size: 13, weight: FontWeight.w500, height: 1.6, color: colors.textMed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Builder(
                // Its own context, so the iPad popover anchors to the button.
                builder: (context) => PrimaryButton(
                  label: ReportCopy.shareAction,
                  icon: Icons.ios_share,
                  enabled: !_busy,
                  onPressed: () => unawaited(_share(context, withText: false)),
                ),
              ),
              const SizedBox(height: 10),
              Builder(
                builder: (context) => _MorePill(
                  enabled: !_busy,
                  onTap: () => unawaited(_share(context, withText: true)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Draws the card and hands it to the system share sheet. Falls back to the
  /// text alone if the picture cannot be made.
  Future<void> _share(BuildContext anchor, {required bool withText}) async {
    if (_busy) return;
    // Read before any await: the anchor's box may be gone afterwards.
    final origin = _originOf(anchor);
    final text = ReportCopy.shareText(widget.report.activeDays);
    setState(() => _busy = true);
    try {
      XFile? picture;
      try {
        picture = await _storyPicture();
      } on Object catch (e) {
        debugPrint('[report] story image failed, sharing text: $e');
      }
      await SharePlus.instance.share(
        picture == null
            ? ShareParams(text: text, sharePositionOrigin: origin)
            : ShareParams(
                files: [picture],
                text: withText ? text : null,
                sharePositionOrigin: origin,
              ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The card as a 1080 × 1920 PNG — written to the system temp directory
  /// where there is one, and held in memory where there is not (the web, or a
  /// temp directory that refuses the write).
  Future<XFile?> _storyPicture() async {
    final boundary = _card.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;
    final image = await boundary.toImage(pixelRatio: 1080 / StoryCard.width);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    final bytes = data.buffer.asUint8List();
    final start = widget.report.weekStart;
    final name = 'aqademiq-week-${start.year}-${_two(start.month)}-${_two(start.day)}.png';
    if (!kIsWeb) {
      try {
        final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$name');
        await file.writeAsBytes(bytes, flush: true);
        return XFile(file.path, mimeType: 'image/png', name: name);
      } on Object {
        // The temp directory refused the write; share_plus can stage the
        // bytes itself.
      }
    }
    return XFile.fromData(bytes, mimeType: 'image/png', name: name);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// iPad presents the share sheet as a popover and needs a rect to anchor it
  /// to (see share_sheet.dart for what happens without one); iPhone ignores it.
  Rect _originOf(BuildContext anchor) {
    final box = anchor.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(anchor);
    return Rect.fromCenter(center: Offset(screen.width / 2, screen.height / 2), width: 1, height: 1);
  }
}

/// The well pill under the primary button (BarPill `fill="well"`): 44 high,
/// the pack's `more` glyph, 17/700.
class _MorePill extends StatelessWidget {
  const _MorePill({required this.onTap, this.enabled = true});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(22)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ic('more', size: 19, color: colors.text),
                const SizedBox(width: 6),
                Text(ReportCopy.shareMore, style: AppText.sans(size: 17, weight: FontWeight.w700, color: colors.text)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The story image (v11 `core-story`): the core's activity shape only, built at
/// 360 × 640 (×3 is 1080 × 1920) with everything inside Instagram's safe band.
/// A specimen plate — the week's core on its side, the one count set huge, Ada
/// signing it — on a night-ice ground in both appearances, so it reads on any
/// feed.
///
/// It is handed [shapeOnly] data and reads nothing but activity from it: a day
/// is filled, open, or not yet here. There is no mood in it to leak.
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.report});

  final WeeklyReport report;

  static const double width = 360;
  static const double height = 640;

  static const Color _ground = Color(0xFF13102A);
  static const Color _sub = Color(0x9EFFFFFF);

  @override
  Widget build(BuildContext context) {
    const ice = AqIcon.iceColor;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _ground)),
          // Two soft glows of ice: one under the core sample, one high left.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.4),
                  radius: 0.9,
                  colors: [ice.withValues(alpha: 0.4), ice.withValues(alpha: 0)],
                  stops: const [0, 0.7],
                  transform: const _SquashY(Alignment(0, 0.4), 0.67),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.84),
                  radius: 0.7,
                  colors: [ice.withValues(alpha: 0.18), ice.withValues(alpha: 0)],
                  stops: const [0, 0.7],
                  transform: const _SquashY(Alignment(-0.6, -0.84), 0.76),
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            left: 30,
            right: 30,
            child: Row(
              children: [
                const AdaMascot(size: 30, bubbles: 2),
                const SizedBox(width: 8),
                Text(
                  ReportCopy.shareBrand,
                  style: AppText.sans(size: 15, weight: FontWeight.w800, letterSpacing: -0.2, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  ReportCopy.weekRange(report.weekStart, report.weekEnd).toUpperCase(),
                  style: AppText.sans(
                    size: 11,
                    weight: FontWeight.w800,
                    letterSpacing: AppText.em(0.14, 11),
                    color: _sub,
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: 134, left: 30, right: 30, child: ColoredBox(color: Color(0x24FFFFFF), child: SizedBox(height: 1))),
          Positioned(
            top: 172,
            left: 24,
            right: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${report.activeDays}',
                  style: AppText.numeral(size: 236, height: 0.8, letterSpacing: -8, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      ReportCopy.storyCount,
                      style: AppText.sans(size: 24, weight: FontWeight.w800, height: 1.15, letterSpacing: -0.4, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: 400, left: 30, child: _CoreSample(days: report.days)),
          Positioned(
            top: 530,
            left: 30,
            right: 30,
            child: Row(
              children: [
                Text(ReportCopy.storyFooter, style: AppText.sans(size: 13, weight: FontWeight.w700, color: _sub)),
                const Spacer(),
                Text(ReportCopy.storyHandle, style: AppText.sans(size: 13, weight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The week's core laid on its side (`StorySample`): seven segments, filled for
/// a day that carried work, dashed for a day that happened empty, bare for a
/// day still to come. Never tinted.
class _CoreSample extends StatelessWidget {
  const _CoreSample({required this.days});

  final List<ReportDay> days;

  static const double _w = 300;
  static const double _h = 78;
  static const Color _iceOnDark = AqIcon.iceOnDarkColor;
  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final n = days.length;
    const outer = Radius.elliptical(_h * 0.22, _h * 0.4);
    const inner = Radius.circular(6);
    return SizedBox(
      width: _w,
      child: Column(
        children: [
          SizedBox(
            width: _w,
            height: _h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x0DFFFFFF),
                      borderRadius: const BorderRadius.all(Radius.elliptical(_h * 0.28, _h / 2)),
                      border: Border.all(color: const Color(0x6BCBBCFD), width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x8C6B5CF0), blurRadius: 60, offset: Offset(0, 22)),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        for (var i = 0; i < n; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Expanded(
                            child: _Segment(
                              day: days[i],
                              radius: BorderRadius.horizontal(
                                left: i == 0 ? outer : inner,
                                right: i == n - 1 ? outer : inner,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // The sheen, and the rim that makes it a drilled cylinder.
                const Positioned(
                  top: 11,
                  left: _h * 0.2,
                  right: _h * 0.2,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x47FFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: -1,
                  width: _h * 0.24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.elliptical(_h * 0.12, _h / 2)),
                      border: Border.all(color: const Color(0xB8FFFFFF), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (var i = 0; i < n; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      _letters[(days[i].weekday - 1).clamp(0, 6)],
                      textAlign: TextAlign.center,
                      style: AppText.sans(
                        size: 10,
                        weight: FontWeight.w800,
                        letterSpacing: AppText.em(0.08, 10),
                        color: days[i].hasActivity ? const Color(0xCCFFFFFF) : const Color(0x66FFFFFF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.day, required this.radius});

  final ReportDay day;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    if (day.hasActivity) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF1ECFF), _CoreSample._iceOnDark, Color(0xFFA294F6)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: const Stack(
          children: [
            Align(alignment: Alignment(-0.4, 0.16), child: _Dot(size: 4, color: Color(0xD9FFFFFF))),
            Align(alignment: Alignment(0.16, 0.44), child: _Dot(size: 2.5, color: Color(0xB3FFFFFF))),
          ],
        ),
      );
    }
    // A day still to come is bare space: the dashed outline means "this day
    // happened and holds nothing", and that is false about tomorrow.
    if (day.isFuture) return const SizedBox.expand();
    return CustomPaint(
      painter: _DashedRRectPainter(radius: radius, color: const Color(0x61CBBCFD)),
      child: const SizedBox.expand(),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.radius, required this.color});

  final BorderRadius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final path = Path()..addRRect(radius.toRRect(Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5)));
    const dash = 4.0;
    const space = 3.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0.0, m.length)), paint);
        d += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color || old.radius != radius;
}

/// Squashes a radial gradient vertically about [center], so a circle becomes
/// the wide ellipse the design's glows are.
class _SquashY extends GradientTransform {
  const _SquashY(this.center, this.factor);

  final Alignment center;
  final double factor;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cy = center.withinRect(bounds).dy;
    // Column-major: y' = factor · y + cy · (1 − factor).
    return Matrix4(1, 0, 0, 0, 0, factor, 0, 0, 0, 0, 1, 0, 0, cy * (1 - factor), 0, 1);
  }
}
