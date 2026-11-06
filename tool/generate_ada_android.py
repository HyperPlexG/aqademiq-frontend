#!/usr/bin/env python3
"""Generate Ada's Android vector drawables from the one geometry.

What comes out of it: the coloured Ada for the session card and the widgets
(ada_stage_N / ada_frost_N), her flat status-bar mask (ic_stat_ada_N /
ic_stat_frost_N), the Quick Settings tile icon (ic_qs_ada), and her empty
outlines for the This week widget (ada_outline, ada_outline_today).

v11 (the icon pack) adds the session card's small icon: aq_brand_ada_mono
(ic_stat_ada) while it runs and the pack's freeze glyph (ic_stat_freeze) while
it is held, and the tile icon becomes aq_brand_ada_mono too. Those are not
redrawn here either: their geometry is read from lib/shared/icons/
aq_glyphs.g.dart, which tool/generate_aq_icons.js emits from
prototypes/v11/aq-icons.js (normalised and verified), so there is one
normaliser and nothing here re-derives the pack. Run that first if the pack
changes. The pack's other native drawables (the session cube, aq_brand_ada,
Ada's moods) come out of tool/generate_ambient_glyphs.js.

She exists three times over — a Flutter CustomPainter, a SwiftUI Shape, and
these — and three hand-drawn mascots drift within two releases. So the Android
copies are not drawn: they are emitted from the same interpolation the painter
uses, with the same coefficients, in the same 60x60 space.

    lib/shared/mascot/ada_mascot.dart   (the source of truth)
    ios/AmbientWidgets/AdaShape.swift   (the same maths, in Swift)

Run after changing any of those:

    python3 tool/generate_ada_android.py
"""
import math
import os
import re

OUT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res', 'drawable')

STAGES = 5  # kMeltStages

# Melting, then frost — the two states of matter, never blended.
MELT = {'body': '#CBBCFD', 'stroke': '#5A44F1', 'ink': '#31237C'}
FROST = {'body': '#D7EEF8', 'stroke': '#9FD6EF', 'ink': '#3F6D84'}


def body_path(m: float) -> str:
    """The cube, sagging into a puddle. Identical maths to the painter."""
    tY, bY = 8 + 15 * m, 50 + 2 * m
    tL, tR = 11 + 7 * m, 49 - 7 * m
    bL, bR = 11 - 6 * m, 49 + 6 * m
    rTop, rBot = 9 + 3 * m, 9 + 13 * m
    sag = 2.5 * m
    return (
        f"M{tL + rTop:.2f},{tY:.2f} "
        f"L{tR - rTop:.2f},{tY:.2f} "
        f"Q{tR:.2f},{tY:.2f} {tR:.2f},{tY + rTop:.2f} "
        f"L{bR:.2f},{bY - rBot:.2f} "
        f"Q{bR:.2f},{bY:.2f} {bR - rBot:.2f},{bY:.2f} "
        f"Q30.00,{bY + sag:.2f} {bL + rBot:.2f},{bY:.2f} "
        f"Q{bL:.2f},{bY:.2f} {bL:.2f},{bY - rBot:.2f} "
        f"L{tL:.2f},{tY + rTop:.2f} "
        f"Q{tL:.2f},{tY:.2f} {tL + rTop:.2f},{tY:.2f} Z"
    )


def face_paths(m: float, frozen: bool) -> str:
    """Melting she is happy — closed, curved eyes and a smile. Frozen she is
    merely held: open dots and a level mouth. Ada is never sad about a pause."""
    tY, bY = 8 + 15 * m, 50 + 2 * m
    cy = (tY + bY) / 2 + 1
    eyeY = cy - 2
    r = 2.7 - 0.5 * m
    dx = 6 - 1.2 * m
    mY = cy + 4.6
    ink = (FROST if frozen else MELT)['ink']
    w = 1.7
    out = []

    if frozen:
        for sx in (-1, 1):
            x = 30 + sx * dx
            out.append(
                f'    <path android:fillColor="{ink}" android:pathData='
                f'"M{x - r * 0.85:.2f},{eyeY:.2f} a{r * 0.85:.2f},{r * 0.85:.2f} 0 1,0 '
                f'{r * 1.7:.2f},0 a{r * 0.85:.2f},{r * 0.85:.2f} 0 1,0 -{r * 1.7:.2f},0 Z" />'
            )
        out.append(
            f'    <path android:strokeColor="{ink}" android:strokeWidth="{w}" '
            f'android:strokeLineCap="round" android:pathData='
            f'"M{30 - 4.4:.2f},{mY:.2f} L{30 + 4.4:.2f},{mY:.2f}" />'
        )
    else:
        for sx in (-1, 1):
            x = 30 + sx * dx
            out.append(
                f'    <path android:strokeColor="{ink}" android:strokeWidth="{w}" '
                f'android:strokeLineCap="round" android:pathData='
                f'"M{x - r:.2f},{eyeY:.2f} Q{x:.2f},{eyeY - r * 1.9:.2f} {x + r:.2f},{eyeY:.2f}" />'
            )
        out.append(
            f'    <path android:strokeColor="{ink}" android:strokeWidth="{w}" '
            f'android:strokeLineCap="round" android:pathData='
            f'"M{30 - 4.4:.2f},{mY:.2f} Q30.00,{mY + 3.6:.2f} {30 + 4.4:.2f},{mY:.2f}" />'
        )
    return "\n".join(out)


def drawable(m: float, frozen: bool) -> str:
    tone = FROST if frozen else MELT
    stroke_w = 3.4 - 1.2 * m
    spurs = ""
    if frozen:
        # At 24dp these, not the hue, are what say "held" — a status bar mask
        # takes every colour away.
        pairs = [(30, 2.5, 30, 10), (30, 50, 30, 57.5), (2.5, 30, 10, 30),
                 (50, 30, 57.5, 30), (10, 10, 15.5, 15.5), (50, 10, 44.5, 15.5),
                 (10, 50, 15.5, 44.5), (50, 50, 44.5, 44.5)]
        spurs = "\n".join(
            f'    <path android:strokeColor="{tone["stroke"]}" android:strokeWidth="1.6" '
            f'android:strokeLineCap="round" android:pathData="M{a},{b} L{c},{d}" />'
            for a, b, c, d in pairs
        )
    gloss = ""
    if m < 0.8:
        fade = 1 - 0.55 * m
        tY = 8 + 15 * m
        gloss = (
            f'    <path android:fillColor="#FFFFFF" android:fillAlpha="{0.85 * fade:.2f}" '
            f'android:pathData="M17.9,{tY + 6:.2f} a2.1,2.1 0 1,0 4.2,0 a2.1,2.1 0 1,0 -4.2,0 Z" />'
        )
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tool/generate_ada_android.py — do not edit by hand.
     Ada at melt {m:.2f}{", frozen" if frozen else ""}. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp"
    android:height="48dp"
    android:viewportWidth="60"
    android:viewportHeight="60">
    <path
        android:fillColor="{tone['body']}"
        android:strokeColor="{tone['stroke']}"
        android:strokeWidth="{stroke_w:.2f}"
        android:pathData="{body_path(m)}" />
{gloss}
{spurs}
{face_paths(m, frozen)}
</vector>
'''


# The mask's canvas. Ada's 60x60 space leaves a wide margin the painter needs
# for her shadow; at 24dp in a status bar that margin is wasted pixels, so the
# masks crop to the 56 units she and her frost spurs actually occupy.
MASK_VIEWPORT = 56
MASK_INSET = 2


def mask(m: float, frozen: bool) -> str:
    """Ada for the status bar: one flat colour, no fill, no stroke, no face.

    Android masks a status-bar icon to a single colour, so everything that
    tells a melting Ada from a frozen one has to survive as outline alone
    (spec §4, and "the constraint that will bite" in §6). Melting, that is the
    sag of the silhouette. Frozen, it is the spurs — and because a spur drawn
    over the body disappears in a mask, the body steps back to let them show.
    """
    stroke_w = 3.4 - 1.2 * m
    body = (
        f'<path android:fillColor="#FFFFFFFF" android:strokeColor="#FFFFFFFF" '
        f'android:strokeWidth="{stroke_w:.2f}" android:strokeLineJoin="round" '
        f'android:pathData="{body_path(m)}" />'
    )
    if frozen:
        pairs = [(30, 2.5, 30, 10), (30, 50, 30, 57.5), (2.5, 30, 10, 30),
                 (50, 30, 57.5, 30), (10, 10, 15.5, 15.5), (50, 10, 44.5, 15.5),
                 (10, 50, 15.5, 44.5), (50, 50, 44.5, 44.5)]
        spurs = "\n".join(
            f'        <path android:strokeColor="#FFFFFFFF" android:strokeWidth="2.6" '
            f'android:strokeLineCap="round" android:pathData="M{a},{b} L{c},{d}" />'
            for a, b, c, d in pairs
        )
        inner = (
            f'        <group android:pivotX="30" android:pivotY="29" '
            f'android:scaleX="0.8" android:scaleY="0.8">\n'
            f'            {body}\n'
            f'        </group>\n{spurs}'
        )
    else:
        inner = f'        {body}'
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tool/generate_ada_android.py — do not edit by hand.
     Ada's status-bar mask at melt {m:.2f}{", frozen" if frozen else ""}: one flat colour. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="{MASK_VIEWPORT}"
    android:viewportHeight="{MASK_VIEWPORT}">
    <group android:translateX="-{MASK_INSET}" android:translateY="-{MASK_INSET}">
{inner}
    </group>
</vector>
'''


# The pack (v11): glyph geometry read from the Dart the pack generator emits.
GLYPHS_DART = os.path.join(os.path.dirname(__file__), '..', 'lib', 'shared', 'icons', 'aq_glyphs.g.dart')
PACK_STROKE = 1.75  # the pack's weight at 24


def pack_glyph(name: str) -> list:
    """One glyph's layers, as tool/generate_aq_icons.js wrote them to Dart.

    Each layer is a dict: id, ops (absolute move/line/cubic/close in the 24 x 24
    grid), role, and the knock stroke width where the pack gives one. Reading
    the generated, verified data means the arcs and quadratics in
    prototypes/v11/aq-icons.js are converted once, by one tool.
    """
    with open(GLYPHS_DART, encoding='utf-8') as fh:
        src = fh.read()
    const = '_g' + ''.join(part[:1].upper() + part[1:] for part in name.split('_'))
    start = src.find('const AqGlyph ' + const + ' = AqGlyph(')
    if start < 0:
        raise SystemExit('aq_glyphs.g.dart: no glyph ' + name)
    block = src[start:src.find('\n);', start)]
    # Only the outline layer list is read; a separate fill-variant list would
    # be refused rather than misread.
    if 'fillLayers:' in block:
        raise SystemExit(name + ': fillLayers are not supported here')
    layers = []
    for lid, pref, extra in re.findall(r"AqLayer\('(\w+)', (_p\d+)((?:, [^)]*)?)\)", block):
        m = re.search(r'const List<double> ' + pref + r' = <double>\[([^\]]*)\];', src)
        if not m:
            raise SystemExit('aq_glyphs.g.dart: no path ' + pref)
        data = [float(v) for v in m.group(1).split(',') if v.strip()]
        role = re.search(r'role: AqRole\.(\w+)', extra)
        sw = re.search(r'strokeWidth: ([\d.]+)', extra)
        layers.append({
            'id': lid,
            'ops': decode(data),
            'role': role.group(1) if role else 'plain',
            'sw': float(sw.group(1)) if sw else None,
            'kfill': 'knockFill: true' in extra,
        })
    if not layers:
        raise SystemExit(name + ': no layers found')
    return layers


def decode(data: list) -> list:
    """The flat op list (0 move, 1 line, 2 cubic, 3 close) as (op, args)."""
    ops, i = [], 0
    while i < len(data):
        op = int(data[i])
        n = {0: 2, 1: 2, 2: 6, 3: 0}[op]
        ops.append((op, data[i + 1:i + 1 + n]))
        i += 1 + n
    return ops


def ops_path(ops: list) -> str:
    out = []
    for op, a in ops:
        if op == 3:
            out.append('Z')
        else:
            pts = ' '.join(f'{a[k]:g},{a[k + 1]:g}' for k in range(0, len(a), 2))
            out.append({0: 'M', 1: 'L', 2: 'C'}[op] + pts)
    return ' '.join(out)


def cubic(p0, p1, p2, p3, u):
    """A point on a cubic and its tangent there."""
    v = 1 - u
    x = v ** 3 * p0[0] + 3 * v * v * u * p1[0] + 3 * v * u * u * p2[0] + u ** 3 * p3[0]
    y = v ** 3 * p0[1] + 3 * v * v * u * p1[1] + 3 * v * u * u * p2[1] + u ** 3 * p3[1]
    dx = 3 * v * v * (p1[0] - p0[0]) + 6 * v * u * (p2[0] - p1[0]) + 3 * u * u * (p3[0] - p2[0])
    dy = 3 * v * v * (p1[1] - p0[1]) + 6 * v * u * (p2[1] - p1[1]) + 3 * u * u * (p3[1] - p2[1])
    return (x, y), (dx, dy)


def subpaths(ops: list) -> list:
    """Each subpath as sampled (point, tangent) pairs, and whether it closed.
    The first point's tangent is None; band() borrows the next one's."""
    out, cur, pts, closed = [], None, [], False
    steps = 12
    for op, a in ops:
        if op == 0:
            if pts:
                out.append((pts, closed))
            cur, pts, closed = (a[0], a[1]), [], False
            pts.append(((a[0], a[1]), None))
        elif op == 1:
            end = (a[0], a[1])
            pts.append((end, (end[0] - cur[0], end[1] - cur[1])))
            cur = end
        elif op == 2:
            p1, p2, p3 = (a[0], a[1]), (a[2], a[3]), (a[4], a[5])
            for k in range(1, steps + 1):
                pts.append(cubic(cur, p1, p2, p3, k / steps))
            cur = p3
        else:
            closed = True
    if pts:
        out.append((pts, closed))
    return out


def area(poly: list) -> float:
    """Shoelace area; positive is screen-clockwise (y points down)."""
    n = len(poly)
    return sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n)) / 2


def poly_path(poly: list) -> str:
    return 'M' + ' L'.join(f'{x:.2f},{y:.2f}' for x, y in poly) + ' Z'


def band(pts: list, width: float) -> list:
    """A stroked open subpath, with round caps, as the polygon a mask can cut
    out — a vector drawable can subtract a filled shape, never a stroke."""
    h = width / 2
    seq = []
    for i, (p, t) in enumerate(pts):
        if t is None:
            t = pts[i + 1][1] if i + 1 < len(pts) and pts[i + 1][1] else (1, 0)
        n = math.hypot(t[0], t[1]) or 1
        seq.append((p, (t[0] / n, t[1] / n)))
    left = [(p[0] - t[1] * h, p[1] + t[0] * h) for p, t in seq]
    right = [(p[0] + t[1] * h, p[1] - t[0] * h) for p, t in seq]

    def cap(p, t, a0):
        """Half a circle round p, from the side at a0 past the tip."""
        a = math.atan2(t[1], t[0])
        return [(p[0] + h * math.cos(a + a0 - math.pi * k / 8), p[1] + h * math.sin(a + a0 - math.pi * k / 8))
                for k in range(1, 8)]

    (pe, te), (ps, ts) = seq[-1], seq[0]
    return left + cap(pe, te, math.pi / 2) + right[::-1] + cap(ps, ts, -math.pi / 2)


def mono_silhouette() -> str:
    """aq_brand_ada_mono as one evenOdd path: the body, with her gloss, eyes
    and mouth (the pack's knock layers) as holes.

    The pack draws the body filled *and* stroked at 1.75, so the silhouette is
    the body grown by half that weight; it is a rounded rect, grown as one.
    Each hole is also wound against the body, so it stays a hole under the
    non-zero rule an older phone applies in place of evenOdd.
    """
    layers = pack_glyph('brand_ada_mono')
    body = [l for l in layers if l['role'] == 'body']
    if len(body) != 1:
        raise SystemExit('brand_ada_mono: expected one body layer')
    ops = body[0]['ops']
    if [op for op, _ in ops] != [0, 1, 2, 1, 2, 1, 2, 1, 2, 3]:
        raise SystemExit('brand_ada_mono: the body is no longer a rounded rect')
    xs = [a[k] for _, a in ops for k in range(0, len(a), 2)]
    ys = [a[k] for _, a in ops for k in range(1, len(a), 2)]
    g = PACK_STROKE / 2
    x0, y0, x1, y1 = min(xs) - g, min(ys) - g, max(xs) + g, max(ys) + g
    r = max(xs) - ops[1][1][0] + g  # the top edge stops this short of the side
    shell = (
        f'M{x0 + r:.2f},{y0:.2f} L{x1 - r:.2f},{y0:.2f} Q{x1:.2f},{y0:.2f} {x1:.2f},{y0 + r:.2f} '
        f'L{x1:.2f},{y1 - r:.2f} Q{x1:.2f},{y1:.2f} {x1 - r:.2f},{y1:.2f} '
        f'L{x0 + r:.2f},{y1:.2f} Q{x0:.2f},{y1:.2f} {x0:.2f},{y1 - r:.2f} '
        f'L{x0:.2f},{y0 + r:.2f} Q{x0:.2f},{y0:.2f} {x0 + r:.2f},{y0:.2f} Z'
    )
    holes = []
    for layer in layers:
        if layer['role'] != 'knock':
            continue
        for pts, _closed in subpaths(layer['ops']):
            if layer['kfill']:
                poly = [p for p, _ in pts]
            else:
                poly = band(pts, layer['sw'] or PACK_STROKE)
            if area(poly) > 0:  # the shell is screen-clockwise
                poly = poly[::-1]
            holes.append(poly_path(poly))
    return ' '.join([shell] + holes)


def mono_icon(what: str) -> str:
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tool/generate_ada_android.py — do not edit by hand.
     {what}
     aq_brand_ada_mono, from the pack's own geometry (aq_glyphs.g.dart). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:fillType="evenOdd"
        android:pathData="{mono_silhouette()}" />
</vector>
'''


def freeze_icon() -> str:
    """The pack's freeze glyph, as the small icon of a held session.

    Every frozen surface in v11 leads with this mark, and a status bar keeps
    nothing but outline — so held has to read as the snowflake, not a tint.
    """
    paths = '\n'.join(
        f'    <path android:strokeColor="#FFFFFFFF" android:strokeWidth="{PACK_STROKE}" '
        f'android:strokeLineCap="round" android:strokeLineJoin="round" '
        f'android:pathData="{ops_path(layer["ops"])}" />'
        for layer in pack_glyph('freeze')
    )
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tool/generate_ada_android.py — do not edit by hand.
     The session card's small icon while it is frozen: the pack's freeze glyph
     (aq_glyphs.g.dart). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
{paths}
</vector>
'''


def tile_icon() -> str:
    """Ada for the Quick Settings tile (spec §7; v11 la-quick).

    A tile icon is tinted to one colour like a status-bar icon, so v11 draws it
    as aq_brand_ada_mono — the same mark as the session card's small icon.
    """
    return mono_icon('Ada for the Quick Settings tile.')


def outline(alpha: str, what: str) -> str:
    """A day the student did not show up, on the This week widget (spec §5).

    Ada's own stage-0 silhouette, stroked and empty — §1's "Outline · nothing
    happened" is literally her, empty. Not a puddle (absence is not depletion)
    and not a generic rounded square, which fills the whole cell while her body
    fills only the middle 38 of 60 units, so empty days drew larger than the
    days that wear her face.

    Two strengths, both measured off §5's own mock: an ordinary missed day is
    white at about 26% on the widget, and today — still open, nothing lost —
    stands out at about 55%. 1.4pt in a 28pt cell is 3 units of her 60.
    """
    return f'''<?xml version="1.0" encoding="utf-8"?>
<!-- GENERATED by tool/generate_ada_android.py — do not edit by hand.
     Ada's empty outline: {what}. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="28dp"
    android:height="28dp"
    android:viewportWidth="60"
    android:viewportHeight="60">
    <path
        android:fillColor="#00000000"
        android:strokeColor="#{alpha}FFFFFF"
        android:strokeWidth="3.0"
        android:strokeLineJoin="round"
        android:pathData="{body_path(0)}" />
</vector>
'''


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    written = []

    def write(name: str, body: str) -> None:
        # UTF-8 explicitly: the headers carry an em dash, and the platform
        # default on Windows (cp1252) silently writes it as a different byte.
        with open(os.path.join(OUT, name), 'w', encoding='utf-8') as fh:
            fh.write(body)
        written.append(name)

    for stage in range(STAGES):
        m = stage / (STAGES - 1)
        write(f'ada_stage_{stage}.xml', drawable(m, frozen=False))
        write(f'ada_frost_{stage}.xml', drawable(m, frozen=True))
        write(f'ic_stat_ada_{stage}.xml', mask(m, frozen=False))
        write(f'ic_stat_frost_{stage}.xml', mask(m, frozen=True))
    write('ic_qs_ada.xml', tile_icon())
    write('ic_stat_ada.xml', mono_icon("The session card's small icon while it runs."))
    write('ic_stat_freeze.xml', freeze_icon())
    write('ada_outline.xml', outline('42', 'a day that did not happen, never a puddle'))
    write('ada_outline_today.xml', outline('8C', 'today, not checked in yet'))
    print(f"wrote {len(written)} drawables to res/drawable/")


if __name__ == '__main__':
    main()
