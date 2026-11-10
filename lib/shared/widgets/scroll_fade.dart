import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/app_colors.dart';

/// The eased ramp every scroll-edge fade runs through (v11 `ADA_RAMP`, and the
/// `BNav` fade mask): position along the fade → opacity of the page colour.
const List<(double, double)> kFadeRamp = [(0.0, 1.0), (0.22, 0.86), (0.48, 0.58), (0.74, 0.24), (1.0, 0.0)];

/// Height of a top fade under a strip of buttons (v11 `ADA_EDGE_H`), and of
/// the ramp a bottom fade adds above the safe-area edge on a page with no nav.
const double kEdgeFadeHeight = 28;

/// A page-colour wash eased through [kFadeRamp], solid for its first [solid]
/// px from its edge. It paints over content so that content dissolves into
/// the page rather than being hard-cut; it is never hit-tested, so it can sit
/// over anything without swallowing a tap.
///
/// The fade is a wash of the page colour, not a mask of the content (as in the
/// design): exact in light, dark and every accent, and free of a saveLayer.
class EdgeFade extends StatelessWidget {
  const EdgeFade.top({
    super.key,
    this.height = kEdgeFadeHeight,
    this.solid = 0,
    this.color,
    this.opacity = 1,
  }) : fromTop = true;

  const EdgeFade.bottom({
    super.key,
    required this.height,
    this.solid = 0,
    this.color,
    this.opacity = 1,
  }) : fromTop = false;

  final double height;

  /// Px from the edge that stay fully page-coloured before the ramp begins.
  final double solid;

  /// The page colour. Defaults to `context.colors.page`.
  final Color? color;

  /// Scales the whole wash, so a fade can arrive gradually as content first
  /// scrolls under it.
  final double opacity;

  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    final page = color ?? context.colors.page;
    final s = height <= 0 ? 0.0 : (solid / height).clamp(0.0, 1.0);
    final k = opacity.clamp(0.0, 1.0);
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                page.withValues(alpha: page.a * k),
                for (final (_, a) in kFadeRamp) page.withValues(alpha: page.a * a * k),
              ],
              stops: [
                0,
                for (final (p, _) in kFadeRamp) s + p * (1 - s),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Watches the scroll views inside [child] and lays the design's scroll-edge
/// fades over them, without the screen having to say where they are:
///
/// * [top] — a [kEdgeFadeHeight] fade along the top edge of the scrolling
///   viewport, so content that scrolls up under a header (a back button, a
///   row of buttons, the status bar) dissolves instead of being cut. It eases
///   in over the first [kEdgeFadeHeight] px of scroll, so a list at rest shows
///   none.
/// * [bottom] — for pages with no bottom nav: a fade along the bottom of this
///   widget that covers the bottom safe-area inset (the home indicator, or
///   Android's navigation bar) and eases out [kEdgeFadeHeight] above it,
///   shown while there is more content below. Tab pages leave this off: the
///   shell draws the nav's own fade (`AppShell`).
///
/// The viewport is found from the scroll notifications themselves, so this
/// works for any vertical [Scrollable] that spans most of the width, however
/// deep it sits. Horizontal scrollers and narrow inner lists are ignored.
class ScrollEdgeFades extends StatefulWidget {
  const ScrollEdgeFades({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = false,
    this.color,
  });

  final Widget child;
  final bool top;
  final bool bottom;

  /// The page colour. Defaults to `context.colors.page`.
  final Color? color;

  @override
  State<ScrollEdgeFades> createState() => _ScrollEdgeFadesState();
}

class _ScrollEdgeFadesState extends State<ScrollEdgeFades> {
  final GlobalKey _stackKey = GlobalKey();

  // Every vertical scroller heard from: how deep it sits and its latest
  // metrics. The page's own scroller is the shallowest; a list nested inside
  // it (a shrink-wrapped group, a card's body) never wins over it.
  final Map<BuildContext, (int, ScrollMetrics)> _seen = {};
  bool _measureScheduled = false;

  // What is drawn: which scroller, where its viewport's top edge sits, and how
  // strong each fade is (0..1).
  BuildContext? _source;
  double? _viewportTop;
  double _topK = 0;
  double _bottomK = 0;

  bool _onScroll(ScrollNotification n) {
    _heard(n.context, n.depth, n.metrics);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    _heard(n.context, n.depth, n.metrics);
    return false;
  }

  void _heard(BuildContext? source, int depth, ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical || source == null) return;
    // Re-insert so the most recently heard sits last and wins a tie.
    _seen
      ..remove(source)
      ..[source] = (depth, metrics);
    // Notifications can arrive mid-layout; measure once the frame is laid out.
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _measureScheduled = false;
        if (mounted) _measure();
      })
      ..ensureVisualUpdate();
  }

  void _measure() {
    final box = _stackKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _seen.removeWhere((c, _) => !c.mounted);

    BuildContext? source;
    ScrollMetrics? metrics;
    RenderBox? viewport;
    var depth = 1 << 30;
    for (final MapEntry(key: c, value: (d, m)) in _seen.entries) {
      final ro = c.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      // A narrow inner list (a card's own scroller) is not the page.
      if (ro.size.width < box.size.width * 0.6) continue;
      if (d <= depth) {
        depth = d;
        source = c;
        metrics = m;
        viewport = ro;
      }
    }
    if (source == null || metrics == null || viewport == null) {
      if (_source != null) setState(() => _source = null);
      return;
    }

    final top = viewport.localToGlobal(Offset.zero, ancestor: box).dy;
    final topK = widget.top ? (metrics.extentBefore / kEdgeFadeHeight).clamp(0.0, 1.0) : 0.0;
    final bottomK = widget.bottom ? (metrics.extentAfter / kEdgeFadeHeight).clamp(0.0, 1.0) : 0.0;
    if (source == _source && top == _viewportTop && topK == _topK && bottomK == _bottomK) return;
    setState(() {
      _source = source;
      _viewportTop = top;
      _topK = topK;
      _bottomK = bottomK;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final viewportTop = _viewportTop;
    // A scroller that has gone away (the page swapped its body) leaves no fade.
    final live = _source?.mounted ?? false;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          key: _stackKey,
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (live && widget.top && viewportTop != null && _topK > 0)
              Positioned(
                top: viewportTop,
                left: 0,
                right: 0,
                child: EdgeFade.top(color: widget.color, opacity: _topK),
              ),
            if (live && widget.bottom && _bottomK > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EdgeFade.bottom(
                  height: inset + kEdgeFadeHeight,
                  solid: inset,
                  color: widget.color,
                  opacity: _bottomK,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
