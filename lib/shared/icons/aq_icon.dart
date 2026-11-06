import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'aq_glyph.dart';
import 'aq_icons.g.dart';
import 'aq_material_icons.dart';

export 'aq_glyph.dart';
export 'aq_icons.g.dart';
export 'aq_material_icons.dart';

/// Draws a glyph of the Aqademiq icon pack, the replacement for Material
/// [Icon]s in the v11 design.
///
/// ```dart
/// AqIcon(AqIcons.freeze)                      // outline, IconTheme colour, 24 px
/// AqIcon(AqIcons.planner, fill: true)          // fill variant (selected tab)
/// AqIcon(AqIcons.cubeSession, progress: 0.4)   // timer layer drawn to 40%
/// AqIcon.named('schedule')                     // a Material name, via AqIcons.materialToAq
/// AqIcon.named('check_circle:fill')            // an aq name, fill variant
/// AqIcon.named('mi:graphic_eq')                // force the Material glyph
/// ```
///
/// Strokes scale with [size] (1.75 at 24 px); caps and joins are round. Roles
/// follow aq-icons.js: in the fill variant `body` layers are filled and `knock`
/// layers erase (the background shows through); in the outline a `cut` slash
/// clears a gap through everything it crosses. The ice glyphs ([AqGlyph.ice])
/// never follow an accent swap: drawn in the theme accent they use [iceColor].
class AqIcon extends StatelessWidget {
  /// Draws [glyph].
  const AqIcon(
    AqGlyph this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.fill = false,
    this.progress,
    this.strokeWidth = AqGlyph.defaultStrokeWidth,
    this.semanticLabel,
  }) : name = null;

  /// Draws the icon a design name resolves to (see [AqResolvedIcon.parse]):
  /// an aq name (`freeze`), an aq name with `:fill`, `task_<name>`, `mi:<name>`
  /// (always Material) or a Material name, which goes through
  /// [AqIcons.materialToAq] and falls back to the Material glyph from
  /// [AqMaterialIcons] when the pack has none.
  const AqIcon.named(
    String this.name, {
    super.key,
    this.size = 24,
    this.color,
    this.fill = false,
    this.progress,
    this.strokeWidth = AqGlyph.defaultStrokeWidth,
    this.semanticLabel,
  }) : glyph = null;

  /// `--aq-ice`: the ice glyphs' colour, pinned whatever the accent.
  static const Color iceColor = Color(0xFF6B5CF0);

  /// `--aq-ice-on-dark`: the ice hero colour on OLED black.
  static const Color iceOnDarkColor = Color(0xFFCBBCFD);

  /// The glyph to draw; null when built with [AqIcon.named].
  final AqGlyph? glyph;

  /// The design name to resolve; null when built with a [glyph].
  final String? name;

  /// Width and height in logical pixels. The 24-unit grid scales to it.
  final double size;

  /// Defaults to the ambient [IconTheme] colour (and its opacity).
  final Color? color;

  /// Draw the fill variant (selected / active). Glyphs without one stay outline.
  final bool fill;

  /// For glyphs with a timer layer (`cube_session`): the fraction of that
  /// layer's length to draw, from its start (top centre, clockwise). Null or
  /// 1 draws it whole, 0 draws nothing of it.
  final double? progress;

  /// Stroke width in grid units (1.75). Scales with [size] like the geometry.
  final double strokeWidth;

  /// Announced by screen readers; without it the icon is decorative, as with
  /// [Icon]. [AqGlyph.label] is a sensible value.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final g = glyph;
    if (g != null) return _buildGlyph(context, g, filled: fill);
    final requested = name ?? '';
    final resolved = AqResolvedIcon.parse(requested);
    final resolvedGlyph = resolved.glyph;
    if (resolvedGlyph != null) {
      return _buildGlyph(context, resolvedGlyph, filled: fill || resolved.fill);
    }
    final material = resolved.materialIcon;
    if (material == null) {
      if (kDebugMode) {
        debugPrint(
          '[aq] no glyph for "$requested" and no Material fallback for '
          '"${resolved.materialName}"; add it to AqMaterialIcons.',
        );
      }
      return SizedBox.square(dimension: size);
    }
    return Icon(
      material,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }

  Widget _buildGlyph(BuildContext context, AqGlyph g, {required bool filled}) {
    final iconTheme = IconTheme.of(context);
    var ink = color ?? iconTheme.color ?? const Color(0xFF000000);
    if (g.ice) {
      final accent = Theme.of(context).extension<AppColors>()?.accent;
      if (accent != null && ink == accent) ink = iceColor;
    }
    final opacity = iconTheme.opacity ?? 1;
    if (opacity < 1) ink = ink.withValues(alpha: ink.a * opacity);
    final painted = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: AqGlyphPainter(
          glyph: g,
          color: ink,
          fill: filled,
          progress: progress,
          strokeWidth: strokeWidth,
        ),
      ),
    );
    final label = semanticLabel;
    return label == null ? painted : Semantics(label: label, child: painted);
  }
}

/// Draws a Tier-2 task icon: the secondary layer at 45% and the primary at
/// 100% of the colour, which defaults to the tag's ink on light surfaces and
/// its hue on dark ones (as the design does).
class AqTaskIcon extends StatelessWidget {
  const AqTaskIcon(
    this.task, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = AqGlyph.defaultStrokeWidth,
    this.semanticLabel,
  });

  final AqTaskGlyph task;
  final double size;

  /// Overrides the tag colour.
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AqIcon(
      task.glyph,
      size: size,
      color: color ?? (dark ? task.hue : task.ink),
      strokeWidth: strokeWidth,
      semanticLabel: semanticLabel,
    );
  }
}

/// What a design icon name resolves to: an aq glyph (possibly a task glyph, and
/// possibly its fill variant) or a Material icon.
@immutable
class AqResolvedIcon {
  const AqResolvedIcon.ofGlyph(AqGlyph this.glyph, {this.fill = false, this.task})
      : materialName = null;

  const AqResolvedIcon.ofMaterial(String this.materialName)
      : glyph = null,
        fill = false,
        task = null;

  /// Resolves [name] exactly as the prototype's `Ic` component does:
  ///
  /// 1. a name in [AqIcons.materialToAq] is replaced by its aq name; a name in
  ///    [AqIcons.materialGaps] stays Material;
  /// 2. `mi:<name>` is always the Material icon `<name>`;
  /// 3. a trailing `:fill` asks for the fill variant;
  /// 4. `task_<name>` is a task icon from [AqTaskIcons];
  /// 5. anything else must be an aq name in [AqIcons.byName], or it falls back
  ///    to the Material icon of the original name.
  factory AqResolvedIcon.parse(String name) {
    if (AqIcons.materialGaps.contains(name)) {
      return AqResolvedIcon.ofMaterial(name);
    }
    final target = AqIcons.materialToAq[name] ?? name;
    if (target.startsWith(_materialPrefix)) {
      return AqResolvedIcon.ofMaterial(target.substring(_materialPrefix.length));
    }
    final fill = target.endsWith(_fillSuffix);
    final base = fill ? target.substring(0, target.length - _fillSuffix.length) : target;
    if (base.startsWith(_taskPrefix)) {
      final task = AqTaskIcons.byName[base.substring(_taskPrefix.length)];
      if (task != null) return AqResolvedIcon.ofGlyph(task.glyph, task: task);
    }
    final glyph = AqIcons.byName[base];
    if (glyph != null) return AqResolvedIcon.ofGlyph(glyph, fill: fill);
    return AqResolvedIcon.ofMaterial(name);
  }

  static const String _materialPrefix = 'mi:';
  static const String _fillSuffix = ':fill';
  static const String _taskPrefix = 'task_';

  /// The aq glyph, or null for a Material icon.
  final AqGlyph? glyph;

  /// The task icon [glyph] belongs to, if it is one.
  final AqTaskGlyph? task;

  /// Whether the fill variant was asked for (`:fill`, or the map says so).
  final bool fill;

  /// The Material icon name, or null for an aq glyph.
  final String? materialName;

  /// Whether this resolved to a Material icon rather than an aq glyph.
  bool get isMaterial => glyph == null;

  /// The Material glyph for [materialName], if [AqMaterialIcons] has it.
  IconData? get materialIcon {
    final n = materialName;
    return n == null ? null : AqMaterialIcons.byName[n];
  }

  @override
  String toString() => isMaterial ? 'AqResolvedIcon(mi:$materialName)' : 'AqResolvedIcon(${glyph?.name}${fill ? ':fill' : ''})';
}

/// Paints an [AqGlyph] scaled from its 24-unit grid into the canvas size (the
/// shorter side, centred). [AqIcon] uses it; it is public for custom painters
/// and tests.
class AqGlyphPainter extends CustomPainter {
  const AqGlyphPainter({
    required this.glyph,
    required this.color,
    this.fill = false,
    this.progress,
    this.strokeWidth = AqGlyph.defaultStrokeWidth,
  });

  final AqGlyph glyph;
  final Color color;
  final bool fill;
  final double? progress;
  final double strokeWidth;

  /// The mask region of the prototype's SVG masks (userSpaceOnUse 0 0 24 24).
  static const Rect _grid = Rect.fromLTWH(0, 0, AqGlyph.gridSize, AqGlyph.gridSize);

  /// Gap a `cut` layer clears around itself, beyond its own stroke (`sw + 3`).
  static const double _cutGap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide / AqGlyph.gridSize;
    final side = AqGlyph.gridSize * scale;
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2)
      ..scale(scale);
    if (glyph.drawsFill(fill: fill)) {
      _paintFill(canvas);
    } else {
      _paintOutline(canvas);
    }
    canvas.restore();
  }

  void _paintOutline(Canvas canvas) {
    final layers = glyph.layers;
    final cuts = layers.where((l) => l.role == AqRole.cut).toList();
    if (cuts.isEmpty) {
      for (final layer in layers) {
        _drawOutlineLayer(canvas, layer);
      }
      return;
    }
    canvas.saveLayer(_grid, Paint());
    for (final layer in layers) {
      if (layer.role != AqRole.cut) _drawOutlineLayer(canvas, layer);
    }
    final gap = _stroke(const Color(0xFF000000), strokeWidth + _cutGap)
      ..blendMode = BlendMode.dstOut;
    for (final layer in cuts) {
      canvas.drawPath(layer.shape, gap);
    }
    canvas.restore();
    for (final layer in cuts) {
      _drawOutlineLayer(canvas, layer);
    }
  }

  void _drawOutlineLayer(Canvas canvas, AqLayer layer) {
    final ink = _ink(layer);
    final path = layer.shape;
    if (layer.paint) canvas.drawPath(path, Paint()..color = ink);
    final stroke = _stroke(ink, strokeWidth);
    final p = progress;
    if (layer.timer && p != null && p < 1) {
      if (p > 0) canvas.drawPath(_trim(path, p), stroke);
    } else {
      canvas.drawPath(path, stroke);
    }
  }

  void _paintFill(Canvas canvas) {
    final layers = glyph.fillVariantLayers;
    final knocks = layers.where((l) => l.role == AqRole.knock).toList();
    if (knocks.isNotEmpty) canvas.saveLayer(_grid, Paint());
    for (final layer in layers) {
      if (layer.role == AqRole.knock) continue;
      final ink = _ink(layer);
      final path = layer.shape;
      if (layer.role == AqRole.body || layer.paint) {
        canvas.drawPath(path, Paint()..color = ink);
      }
      canvas.drawPath(path, _stroke(ink, strokeWidth));
    }
    if (knocks.isEmpty) return;
    for (final layer in knocks) {
      final eraser = (layer.knockFill
          ? Paint()
          : _stroke(const Color(0xFF000000), layer.strokeWidth ?? strokeWidth))
        ..blendMode = BlendMode.dstOut;
      canvas.drawPath(layer.knockShape, eraser);
    }
    canvas.restore();
  }

  Color _ink(AqLayer layer) =>
      layer.opacity >= 1 ? color : color.withValues(alpha: color.a * layer.opacity);

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// The first [fraction] of [source]'s total length, across its contours.
  static Path _trim(Path source, double fraction) {
    final metrics = source.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * fraction;
    final out = Path();
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = math.min(remaining, metric.length);
      out.addPath(metric.extractPath(0, take), Offset.zero);
      remaining -= take;
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant AqGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.fill != fill ||
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth;
}
