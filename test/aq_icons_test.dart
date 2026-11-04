import 'dart:ui' as ui;

import 'package:aqademiq/core/theme/app_colors.dart';
import 'package:aqademiq/shared/icons/aq_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _ink = Color(0xFF000000);

Widget _host(Widget child, {ThemeData? theme}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Theme(
    data: theme ?? ThemeData(),
    child: Center(child: child),
  ),
);

/// The painter of the single [AqIcon] on screen.
AqGlyphPainter _painterOf(WidgetTester tester) {
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(AqIcon),
      matching: find.byType(CustomPaint),
    ),
  );
  return customPaint.painter! as AqGlyphPainter;
}

/// Rasterises [painter] at 10 px per grid unit; the returned probe gives the
/// alpha (0..255) of the pixel at grid point (x, y).
Future<int Function(double x, double y)> _raster(
  WidgetTester tester,
  AqGlyphPainter painter,
) async {
  const scale = 10.0;
  final side = (AqGlyph.gridSize * scale).toInt();
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), Size.square(side.toDouble()));
  final picture = recorder.endRecording();
  final bytes = await tester.runAsync(() async {
    final image = await picture.toImage(side, side);
    final data = await image.toByteData();
    image.dispose();
    return data;
  });
  picture.dispose();
  final data = bytes!;
  int alphaAt(double x, double y) {
    final px = (x * scale).floor();
    final py = (y * scale).floor();
    return data.getUint8((py * side + px) * 4 + 3);
  }

  return alphaAt;
}

void main() {
  group('every glyph paints', () {
    for (final entry in AqIcons.byName.entries) {
      testWidgets(entry.key, (tester) async {
        for (final size in const <double>[16, 24, 48]) {
          for (final fill in const <bool>[false, true]) {
            for (final progress in const <double?>[null, 0.5]) {
              await tester.pumpWidget(
                _host(
                  AqIcon(
                    entry.value,
                    size: size,
                    fill: fill,
                    progress: progress,
                  ),
                ),
              );
              expect(tester.takeException(), isNull);
              expect(tester.getSize(find.byType(AqIcon)), Size.square(size));
            }
          }
        }
      });
    }

    testWidgets('every task icon', (tester) async {
      for (final task in AqTaskIcons.byName.values) {
        for (final size in const <double>[16, 24, 48]) {
          await tester.pumpWidget(_host(AqTaskIcon(task, size: size)));
          expect(tester.takeException(), isNull, reason: task.name);
        }
      }
    });
  });

  group('generated tables', () {
    test('byName keys are the glyph names', () {
      for (final entry in AqIcons.byName.entries) {
        expect(entry.value.name, entry.key);
      }
      for (final entry in AqTaskIcons.byName.entries) {
        expect(entry.value.name, entry.key);
        expect(entry.value.glyph.layers, hasLength(2));
      }
    });

    test('every materialToAq target exists', () {
      for (final entry in AqIcons.materialToAq.entries) {
        final resolved = AqResolvedIcon.parse(entry.key);
        expect(
          resolved.isMaterial,
          isFalse,
          reason: '${entry.key} -> ${entry.value}',
        );
      }
    });

    test('every gap in the pack has a Material fallback', () {
      for (final gap in AqIcons.materialGaps) {
        expect(AqMaterialIcons.byName[gap], isNotNull, reason: gap);
        expect(AqResolvedIcon.parse(gap).materialIcon, isNotNull, reason: gap);
      }
    });

    test('the ice set', () {
      expect(AqIcons.iceNames, <String>{'freeze', 'thaw', 'never_open', 'shield'});
      expect(AqIcons.ice.map((g) => g.name).toSet(), AqIcons.iceNames);
      expect(AqIcons.byName.values.where((g) => g.ice).toSet(), AqIcons.ice);
    });

    test('fill only where the glyph has a fill variant', () {
      expect(AqIcons.freeze.drawsFill(fill: true), isFalse);
      expect(AqIcons.planner.drawsFill(fill: true), isTrue);
      expect(AqIcons.planner.drawsFill(fill: false), isFalse);
      expect(AqIcons.brandAdaMono.drawsFill(fill: false), isTrue);
    });
  });

  group('AqResolvedIcon.parse', () {
    test('an aq name', () {
      final resolved = AqResolvedIcon.parse('freeze');
      expect(resolved.glyph, same(AqIcons.freeze));
      expect(resolved.fill, isFalse);
      expect(resolved.isMaterial, isFalse);
    });

    test('an aq name with :fill', () {
      final resolved = AqResolvedIcon.parse('check_circle:fill');
      expect(resolved.glyph, same(AqIcons.checkCircle));
      expect(resolved.fill, isTrue);
    });

    test('mi: forces the Material glyph', () {
      final resolved = AqResolvedIcon.parse('mi:graphic_eq');
      expect(resolved.isMaterial, isTrue);
      expect(resolved.materialName, 'graphic_eq');
      expect(resolved.materialIcon, Icons.graphic_eq_outlined);
    });

    test('a Material name goes through materialToAq', () {
      expect(AqResolvedIcon.parse('schedule').glyph, same(AqIcons.time));
      expect(AqResolvedIcon.parse('ac_unit').glyph, same(AqIcons.freeze));
      expect(AqResolvedIcon.parse('radio_button_unchecked').glyph, same(AqIcons.aqxRing));
      final circle = AqResolvedIcon.parse('check_circle');
      expect(circle.glyph, same(AqIcons.checkCircle));
      expect(circle.fill, isTrue);
    });

    test('task names', () {
      final slideshow = AqResolvedIcon.parse('slideshow');
      expect(slideshow.task, same(AqTaskIcons.presentation));
      expect(slideshow.glyph, same(AqTaskIcons.presentation.glyph));
      expect(AqResolvedIcon.parse('task_exam').task, same(AqTaskIcons.exam));
    });

    test('gaps, unmapped and unknown names stay Material', () {
      final sell = AqResolvedIcon.parse('sell');
      expect(sell.isMaterial, isTrue);
      expect(sell.materialIcon, Icons.sell_outlined);
      expect(AqResolvedIcon.parse('map').materialIcon, Icons.map_outlined);
      final unknown = AqResolvedIcon.parse('not_an_icon_anywhere');
      expect(unknown.isMaterial, isTrue);
      expect(unknown.materialIcon, isNull);
    });
  });

  group('AqIcon', () {
    testWidgets('named() draws a glyph or a Material Icon', (tester) async {
      await tester.pumpWidget(_host(const AqIcon.named('freeze')));
      expect(_painterOf(tester).glyph, same(AqIcons.freeze));

      await tester.pumpWidget(_host(const AqIcon.named('check_circle:fill')));
      final painter = _painterOf(tester);
      expect(painter.glyph, same(AqIcons.checkCircle));
      expect(painter.fill, isTrue);

      await tester.pumpWidget(_host(const AqIcon.named('mi:graphic_eq', size: 20)));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.graphic_eq_outlined);
      expect(icon.size, 20);

      await tester.pumpWidget(_host(const AqIcon.named('not_an_icon_anywhere', size: 20)));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AqIcon)), const Size.square(20));
    });

    testWidgets('colour defaults to the IconTheme', (tester) async {
      await tester.pumpWidget(
        _host(
          const IconTheme(
            data: IconThemeData(color: Color(0xFF123456)),
            child: AqIcon(AqIcons.add),
          ),
        ),
      );
      expect(_painterOf(tester).color, const Color(0xFF123456));
    });

    testWidgets('ice glyphs in the accent are pinned to the ice colour', (tester) async {
      final accent = AppAccent.pink.color;
      final theme = ThemeData(
        extensions: <ThemeExtension<dynamic>>[AppColors.light(AppAccent.pink)],
      );
      for (final glyph in AqIcons.ice) {
        await tester.pumpWidget(_host(AqIcon(glyph, color: accent), theme: theme));
        expect(_painterOf(tester).color, AqIcon.iceColor, reason: glyph.name);
      }

      // Through a Material name ('ac_unit' -> freeze) and the ambient IconTheme.
      await tester.pumpWidget(_host(AqIcon.named('ac_unit', color: accent), theme: theme));
      expect(_painterOf(tester).color, AqIcon.iceColor);
      await tester.pumpWidget(
        _host(
          IconTheme(
            data: IconThemeData(color: accent),
            child: const AqIcon(AqIcons.thaw),
          ),
          theme: theme,
        ),
      );
      expect(_painterOf(tester).color, AqIcon.iceColor);

      // Another colour, or a glyph outside the ice set, is left alone.
      await tester.pumpWidget(
        _host(const AqIcon(AqIcons.freeze, color: Color(0xFF111111)), theme: theme),
      );
      expect(_painterOf(tester).color, const Color(0xFF111111));
      await tester.pumpWidget(_host(AqIcon(AqIcons.add, color: accent), theme: theme));
      expect(_painterOf(tester).color, accent);
    });

    testWidgets('task icons wear the tag ink in light and the hue in dark', (tester) async {
      await tester.pumpWidget(_host(const AqTaskIcon(AqTaskIcons.exam)));
      expect(_painterOf(tester).color, AqTaskIcons.exam.ink);

      await tester.pumpWidget(
        _host(
          const AqTaskIcon(AqTaskIcons.exam),
          theme: ThemeData(brightness: Brightness.dark),
        ),
      );
      expect(_painterOf(tester).color, AqTaskIcons.exam.hue);
    });
  });

  group('roles, at the pixel', () {
    testWidgets('knock layers erase the fill variant', (tester) async {
      final fill = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.checkCircle, color: _ink, fill: true),
      );
      expect(fill(12, 7), 255, reason: 'the disc is filled');
      expect(fill(11, 15.25), 0, reason: 'the tick is knocked out of it');

      final outline = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.checkCircle, color: _ink),
      );
      expect(outline(12, 7), 0, reason: 'the outline is not filled');
      expect(outline(12, 3), 255, reason: 'the ring is stroked');
    });

    testWidgets('a cut clears a gap through what it crosses', (tester) async {
      final bell = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.notifications, color: _ink),
      );
      final off = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.notificationsOff, color: _ink),
      );
      // On the bell's base line, 1.6 units from the slash: inside the gap.
      expect(bell(15.25, 17.5), 255);
      expect(off(15.25, 17.5), 0);
      // The slash itself is drawn on top.
      expect(off(12, 12), 255);
    });

    testWidgets('a timer layer draws only its progress', (tester) async {
      Future<int Function(double x, double y)> cube(double? progress) => _raster(
        tester,
        AqGlyphPainter(glyph: AqIcons.cubeSession, color: _ink, progress: progress),
      );
      // The cube runs clockwise from top centre: (15.25, 3) is 5% along it,
      // (3, 12) is 75% along it.
      final quarter = await cube(0.25);
      expect(quarter(15.25, 3), 255);
      expect(quarter(3, 12), 0);
      final whole = await cube(null);
      expect(whole(3, 12), 255);
      final none = await cube(0);
      expect(none(15.25, 3), 0);
    });

    testWidgets('fillLayers replace the layers in the fill variant', (tester) async {
      final fill = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.insights, color: _ink, fill: true),
      );
      final outline = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.insights, color: _ink),
      );
      expect(fill(18, 18), 255, reason: 'the area under the curve');
      expect(outline(18, 18), 0);
    });

    testWidgets('a fill-only glyph is always its silhouette', (tester) async {
      final ada = await _raster(
        tester,
        const AqGlyphPainter(glyph: AqIcons.brandAdaMono, color: _ink),
      );
      expect(ada(17, 18), 255, reason: 'the body is filled');
      expect(ada(12, 15.8), 0, reason: 'the mouth is knocked out');
    });

    testWidgets('the secondary task layer is drawn at 45%', (tester) async {
      final exam = await _raster(
        tester,
        AqGlyphPainter(glyph: AqTaskIcons.exam.glyph, color: _ink),
      );
      expect(exam(12, 3), 255, reason: 'primary layer');
      expect(exam(12, 7), closeTo(115, 3), reason: 'secondary layer');
    });
  });
}
