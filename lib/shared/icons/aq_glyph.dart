import 'dart:ui' show Color, Path;

import 'package:flutter/foundation.dart' show immutable;

/// What a layer does beyond being stroked (the `role` in aq-icons.js).
enum AqRole {
  /// No role: stroked in both variants.
  plain,

  /// Filled (and stroked) in the fill variant; stroked in the outline.
  body,

  /// Erases what is under it in the fill variant (a mask), so the background
  /// shows through; stroked like [plain] in the outline.
  knock,

  /// A slash: in the outline it clears a gap (stroke width + 3) through every
  /// other layer, then draws itself on top.
  cut,
}

/// One layer of a glyph. Layer order is draw (and animation) order.
@immutable
class AqLayer {
  const AqLayer(
    this.id,
    this.path, {
    this.role = AqRole.plain,
    this.paint = false,
    this.timer = false,
    this.opacity = 1,
    this.strokeWidth,
    this.knockFill = false,
    this.fillPath,
  });

  /// The layer id in the source (`body`, `ring`, `slash`, ...).
  final String id;

  /// Path data in the 24 x 24 grid (see [aqPathFromData] for the op codes).
  final List<double> path;

  final AqRole role;

  /// Also filled with the colour in both variants (`paint: true`).
  final bool paint;

  /// Drawn only up to `AqIcon.progress` of its length (the cube timer).
  final bool timer;

  /// Alpha multiplier for this layer (the secondary task-icon layer is 0.45).
  final double opacity;

  /// Stroke width used when this layer knocks out (`sw`). Null = the icon's.
  final double? strokeWidth;

  /// A knock that erases its filled shape instead of its stroke (`kfill`).
  final bool knockFill;

  /// Alternative geometry used when this layer knocks out (`fd`).
  final List<double>? fillPath;

  /// [path] as a cached [Path].
  Path get shape => aqPathFromData(path);

  /// The geometry this layer erases with in the fill variant.
  Path get knockShape => aqPathFromData(fillPath ?? path);
}

/// A glyph of the Aqademiq icon pack: layers drawn in a 24 x 24 grid.
///
/// Instances are generated (see `AqIcons` and `AqTaskIcons`); never build them by
/// hand. Edit prototypes/v11/aq-icons.js and run `node tool/generate_aq_icons.js`.
@immutable
class AqGlyph {
  const AqGlyph(
    this.name, {
    required this.layers,
    this.label,
    this.fillLayers,
    this.hasFill = false,
    this.fillOnly = false,
    this.ice = false,
  });

  /// The pack's grid: every coordinate is in `0..gridSize`.
  static const double gridSize = 24;

  /// The pack's stroke width at 24 px.
  static const double defaultStrokeWidth = 1.75;

  /// The design name (`freeze`, `chevron_right`, `task_exam`, ...).
  final String name;

  /// The design's label, a sensible default for a semantic label.
  final String? label;

  /// The outline layers.
  final List<AqLayer> layers;

  /// Layers of the fill variant when they differ from [layers].
  final List<AqLayer>? fillLayers;

  /// Whether the glyph has a fill variant (`fill: true`). Asking an icon without
  /// one to fill draws the outline, as the prototype does.
  final bool hasFill;

  /// Only ever drawn as its fill silhouette (`fillOnly: true`).
  final bool fillOnly;

  /// One of the ice glyphs, pinned to the ice colour when drawn in the accent.
  final bool ice;

  /// Whether a request for [fill] actually draws the fill variant.
  bool drawsFill({required bool fill}) => fillOnly || (fill && hasFill);

  /// The layers drawn by the fill variant.
  List<AqLayer> get fillVariantLayers => fillLayers ?? layers;

  @override
  String toString() => 'AqGlyph($name)';
}

/// A Tier-2 task icon: a two-layer [glyph] plus its study-tag colours.
@immutable
class AqTaskGlyph {
  const AqTaskGlyph({
    required this.name,
    required this.label,
    required this.tag,
    required this.hue,
    required this.ink,
    required this.glyph,
  });

  /// The task name (`exam`); the design addresses it as `task_exam`.
  final String name;

  /// The design label (`Exam`).
  final String label;

  /// The study tag whose colours this icon wears (`exam`, `class`, ...).
  final String tag;

  /// The tag hue: the glyph colour on dark surfaces.
  final Color hue;

  /// The tag ink step: the glyph colour on light surfaces (at least 3:1).
  final Color ink;

  /// The two layers: the secondary (45%) first, the primary (100%) on top.
  final AqGlyph glyph;

  @override
  String toString() => 'AqTaskGlyph($name)';
}

/// Path op codes used by the generated data.
abstract final class AqPathOp {
  /// `moveTo(x, y)`: followed by 2 numbers.
  static const int moveTo = 0;

  /// `lineTo(x, y)`: followed by 2 numbers.
  static const int lineTo = 1;

  /// `cubicTo(x1, y1, x2, y2, x, y)`: followed by 6 numbers.
  static const int cubicTo = 2;

  /// `close()`: no numbers.
  static const int close = 3;
}

final Expando<Path> _pathCache = Expando<Path>('AqGlyph path');

/// Builds (once, then caches) the [Path] for generated path data: a flat list of
/// [AqPathOp] codes, each followed by its absolute coordinates.
Path aqPathFromData(List<double> data) => _pathCache[data] ??= _buildPath(data);

Path _buildPath(List<double> data) {
  final path = Path();
  var i = 0;
  while (i < data.length) {
    final op = data[i].toInt();
    if (op == AqPathOp.moveTo) {
      path.moveTo(data[i + 1], data[i + 2]);
      i += 3;
    } else if (op == AqPathOp.lineTo) {
      path.lineTo(data[i + 1], data[i + 2]);
      i += 3;
    } else if (op == AqPathOp.cubicTo) {
      path.cubicTo(
        data[i + 1],
        data[i + 2],
        data[i + 3],
        data[i + 4],
        data[i + 5],
        data[i + 6],
      );
      i += 7;
    } else if (op == AqPathOp.close) {
      path.close();
      i += 1;
    } else {
      throw StateError('Bad aq path op $op at index $i');
    }
  }
  return path;
}
