import SwiftUI

/// Ada, drawn natively.
///
/// She already exists as a Flutter `CustomPainter`, and Flutter cannot render
/// inside a WidgetKit extension — so she has to exist a second time here. Three
/// hand-drawn mascots drift within two releases, so the geometry below is not
/// redrawn by eye: it is the same interpolation the painter uses, in the same
/// 60×60 design space, with the same coefficients.
///
/// `lib/shared/mascot/ada_mascot.dart`:
/// ```
/// tY   = 8  + 15 * m      bY   = 50 + 2  * m
/// tL   = 11 + 7  * m      tR   = 49 - 7  * m
/// bL   = 11 - 6  * m      bR   = 49 + 6  * m
/// rTop = 9  + 3  * m      rBot = 9  + 13 * m
/// sag  = 2.5 * m
/// ```
/// Change one of those and change it in both places, or she starts drifting.
struct AdaShape: Shape {
    /// 0 = a whole cube, 1 = a puddle.
    var melt: Double

    var animatableData: Double {
        get { melt }
        set { melt = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let m = min(max(melt, 0), 1)
        let scale = min(rect.width, rect.height) / 60
        func x(_ v: Double) -> CGFloat { rect.minX + v * scale }
        func y(_ v: Double) -> CGFloat { rect.minY + v * scale }

        let tY = 8 + 15 * m
        let bY = 50 + 2 * m
        let tL = 11 + 7 * m
        let tR = 49 - 7 * m
        let bL = 11 - 6 * m
        let bR = 49 + 6 * m
        let rTop = 9 + 3 * m
        let rBot = 9 + 13 * m
        let sag = 2.5 * m

        var path = Path()
        // Top edge, left to right.
        path.move(to: CGPoint(x: x(tL + rTop), y: y(tY)))
        path.addLine(to: CGPoint(x: x(tR - rTop), y: y(tY)))
        path.addQuadCurve(
            to: CGPoint(x: x(tR), y: y(tY + rTop)),
            control: CGPoint(x: x(tR), y: y(tY))
        )
        // Right side down to the base.
        path.addLine(to: CGPoint(x: x(bR), y: y(bY - rBot)))
        path.addQuadCurve(
            to: CGPoint(x: x(bR - rBot), y: y(bY)),
            control: CGPoint(x: x(bR), y: y(bY))
        )
        // The base, sagging in the middle — this is what makes her melt rather
        // than merely shrink.
        path.addQuadCurve(
            to: CGPoint(x: x(bL + rBot), y: y(bY)),
            control: CGPoint(x: x(30), y: y(bY + sag))
        )
        path.addQuadCurve(
            to: CGPoint(x: x(bL), y: y(bY - rBot)),
            control: CGPoint(x: x(bL), y: y(bY))
        )
        // Left side back up to the top.
        path.addLine(to: CGPoint(x: x(tL), y: y(tY + rTop)))
        path.addQuadCurve(
            to: CGPoint(x: x(tL + rTop), y: y(tY)),
            control: CGPoint(x: x(tL), y: y(tY))
        )
        path.closeSubpath()
        return path
    }
}

/// The palette, straight from the design tokens.
///
/// Melting and frost are not two tints of one thing — they are two states of
/// matter, and they have to read as different from across a desk, which is why
/// the fill, the stroke and the ink all move together.
enum AdaPalette {
    // Melting.
    static let body = Color(red: 0.796, green: 0.737, blue: 0.992)      // #cbbcfd
    static let stroke = Color(red: 0.353, green: 0.267, blue: 0.945)    // #5a44f1
    static let ink = Color(red: 0.192, green: 0.137, blue: 0.486)       // #31237c

    // Frost.
    static let frostBody = Color(red: 0.843, green: 0.933, blue: 0.973) // #d7eef8
    static let frostStroke = Color(red: 0.624, green: 0.839, blue: 0.937) // #9fd6ef
    static let frostInk = Color(red: 0.247, green: 0.427, blue: 0.518)  // #3f6d84

    static let accent = Color(red: 0.420, green: 0.361, blue: 0.941)    // #6b5cf0
    static let frostLit = Color(red: 0.624, green: 0.839, blue: 0.937)  // #9fd6ef
    static let drip = Color(red: 0.749, green: 0.902, blue: 0.961)      // #bfe6f5
}

/// Ada at a melt stage, with the face and the frost the state calls for.
///
/// She has to survive 22pt in the minimal Island, a flat monochrome mask in the
/// Android status bar, and Always-On dimming — so the silhouette carries the
/// meaning and everything else only decorates it. The gloss, the cheeks and the
/// shadow are the first things dropped as she gets smaller.
struct AdaView: View {
    /// `0..<kMeltStages`, straight from the shared state.
    var stage: Int

    /// Frost, not a pause glyph: she stops mid-melt and changes state of matter.
    var frozen: Bool = false

    /// Draw the face. Dropped at small sizes, where it is noise not information.
    var showsFace: Bool = true

    private var melt: Double { Double(min(max(stage, 0), 4)) / 4 }

    private var fill: Color { frozen ? AdaPalette.frostBody : AdaPalette.body }
    private var line: Color { frozen ? AdaPalette.frostStroke : AdaPalette.stroke }
    private var ink: Color { frozen ? AdaPalette.frostInk : AdaPalette.ink }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let u = side / 60          // one unit of the 60x60 design space
            let m = melt

            ZStack {
                // The puddle she is standing in — soft, and it spreads as she goes.
                Ellipse()
                    .fill(Color.black.opacity(0.13))
                    .frame(width: (26 + 14 * m) * u, height: 4 * u)
                    .position(x: 30 * u, y: (53 + 2 * m) * u)
                    .blur(radius: 1.2 * u)

                AdaShape(melt: m)
                    .fill(
                        // Ice is lit from above: a little brighter at the top.
                        LinearGradient(
                            colors: [fill.opacity(1), fill.opacity(0.82)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                AdaShape(melt: m)
                    .stroke(line, lineWidth: max(0.8, (3.4 - 1.2 * m) * u))

                if showsFace && side >= 26 {
                    // Inner sheen: a soft second body inset, so she reads as
                    // translucent rather than as a flat sticker.
                    AdaShape(melt: m)
                        .fill(Color.white.opacity(0.22))
                        .scaleEffect(0.86)
                        .blur(radius: 0.6 * u)

                    gloss(u: u, m: m)
                }

                if frozen {
                    // At 22pt these, not the hue, are what say "held" — colour
                    // is the first thing an Always-On display takes away.
                    FrostSpurs()
                        .stroke(AdaPalette.frostStroke,
                                style: StrokeStyle(lineWidth: max(0.9, 1.6 * u), lineCap: .round))
                        .opacity(0.95)
                }

                if showsFace {
                    face(u: u, m: m)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    /// The highlight that makes her ice rather than plastic: one bright bead and
    /// a streak along the top edge, both fading as she loses volume.
    private func gloss(u: CGFloat, m: Double) -> some View {
        let tY = 8 + 15 * m
        let fade = 1 - 0.55 * m
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.85 * fade))
                .frame(width: 4.2 * u, height: 4.2 * u)
                .position(x: 20 * u, y: (tY + 6) * u)
            Circle()
                .fill(Color.white.opacity(0.55 * fade))
                .frame(width: 2.2 * u, height: 2.2 * u)
                .position(x: 25.5 * u, y: (tY + 4.2) * u)
        }
        .frame(width: 60 * u, height: 60 * u)
    }

    /// Eyes and mouth on the painter's own interpolation: the eyes shrink and
    /// converge as she goes, and the face is held until she is spent.
    ///
    /// Melting she is happy — closed, curved eyes and a smile. Frozen she is
    /// merely held: open dots and a level mouth, no distress. Ada is never sad
    /// about being paused.
    private func face(u: CGFloat, m: Double) -> some View {
        let tY = 8 + 15 * m
        let bY = 50 + 2 * m
        let faceCY = (tY + bY) / 2 + 1
        let eyeY = faceCY - 2
        let eyeR = 2.7 - 0.5 * m
        let eyeDX = 6 - 1.2 * m
        let mouthY = faceCY + 4.6
        let w = max(0.9, 1.7 * u)

        return ZStack {
            if frozen {
                Circle().fill(ink)
                    .frame(width: eyeR * 1.7 * u, height: eyeR * 1.7 * u)
                    .position(x: (30 - eyeDX) * u, y: eyeY * u)
                Circle().fill(ink)
                    .frame(width: eyeR * 1.7 * u, height: eyeR * 1.7 * u)
                    .position(x: (30 + eyeDX) * u, y: eyeY * u)
                // Level, not a frown.
                Path { p in
                    p.move(to: CGPoint(x: (30 - 4.4) * u, y: mouthY * u))
                    p.addLine(to: CGPoint(x: (30 + 4.4) * u, y: mouthY * u))
                }
                .stroke(ink, style: StrokeStyle(lineWidth: w, lineCap: .round))
            } else {
                // Closed, happy eyes — two arcs, not dots.
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Path { p in
                        let cx = (30 + side * eyeDX) * u
                        p.move(to: CGPoint(x: cx - eyeR * u, y: eyeY * u))
                        p.addQuadCurve(
                            to: CGPoint(x: cx + eyeR * u, y: eyeY * u),
                            control: CGPoint(x: cx, y: (eyeY - eyeR * 1.9) * u)
                        )
                    }
                    .stroke(ink, style: StrokeStyle(lineWidth: w, lineCap: .round))
                }
                Path { p in
                    p.move(to: CGPoint(x: (30 - 4.4) * u, y: mouthY * u))
                    p.addQuadCurve(
                        to: CGPoint(x: (30 + 4.4) * u, y: mouthY * u),
                        control: CGPoint(x: 30 * u, y: (mouthY + 3.6) * u)
                    )
                }
                .stroke(ink, style: StrokeStyle(lineWidth: w, lineCap: .round))
            }
        }
        .frame(width: 60 * u, height: 60 * u)
    }
}

/// The eight spurs that say frozen from across a desk.
private struct FrostSpurs: Shape {
    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 60
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * u, y: rect.minY + y * u)
        }
        var path = Path()
        let spurs: [(Double, Double, Double, Double)] = [
            (30, 2.5, 30, 10), (30, 50, 30, 57.5),
            (2.5, 30, 10, 30), (50, 30, 57.5, 30),
            (10, 10, 15.5, 15.5), (50, 10, 44.5, 15.5),
            (10, 50, 15.5, 44.5), (50, 50, 44.5, 44.5),
        ]
        for (x1, y1, x2, y2) in spurs {
            path.move(to: p(x1, y1))
            path.addLine(to: p(x2, y2))
        }
        return path
    }
}

// MARK: - The icon pack

// The v11 surfaces draw the Aqademiq icon pack — aq_cube_session is the
// session's timer, aq_brand_ada is Ada — and none of them can run Flutter, so
// the pack exists here a second time. Like Ada above it is not redrawn by eye:
// the data in the GENERATED block at the end of this file is emitted from
// prototypes/v11/aq-icons.js by `node tool/generate_ambient_glyphs.js`. It lives
// in this file rather than one of its own because this is the one source both
// the widget extension and the watch compile; a new file would also need
// ios/add_widget_target.rb and ios/add_watch_target.rb re-run.

/// The pack's pinned colours. Ice never follows an accent swap.
enum AqColor {
    /// `--aq-ice`: ice on light grounds.
    static let ice = Color(red: 0.420, green: 0.361, blue: 0.941)        // #6B5CF0
    /// `--aq-ice-on-dark`: ice on black — the Island, StandBy, the watch.
    static let iceOnDark = Color(red: 0.796, green: 0.737, blue: 0.992)  // #CBBCFD
}

extension Color {
    /// `0xRRGGBB`, as the generated art writes its colours.
    init(aqRGB rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

/// One layer of a pack glyph, in the 24 x 24 grid.
struct AqGlyphLayer {
    let path: [CGFloat]
    /// Also filled (`paint: true` in the pack).
    var paint: Bool = false
    /// Drawn only to the time left (`timer: true`; aq_cube_session's cube).
    var timer: Bool = false
}

/// A pack glyph: outline layers stroked at the pack's weight.
struct AqGlyph {
    let layers: [AqGlyphLayer]
}

/// One painted shape of the pack's colour art (aq_brand_ada, Ada's moods).
struct AqArtLayer {
    let path: [CGFloat]
    var fill: UInt32? = nil
    var fillOpacity: Double = 1
    var stroke: UInt32? = nil
    var strokeWidth: CGFloat = 1
    var strokeOpacity: Double = 1
    var roundCap: Bool = false
    var roundJoin: Bool = false
}

/// Colour art in its own design box (the SVG viewBox).
struct AqArt {
    let box: CGRect
    let layers: [AqArtLayer]
}

/// One path of the pack, fitted (centred, aspect kept) to the rect it is drawn
/// in — stroked at the pack's weight, or filled when `lineWidth` is nil.
///
/// The stroke is turned into its outline here and filled by the caller, so the
/// weight scales with the glyph exactly as the SVG's does.
struct AqPathShape: Shape {
    let data: [CGFloat]
    var box: CGRect = CGRect(x: 0, y: 0, width: 24, height: 24)
    /// In design units; the pack's 1.75 at 24.
    var lineWidth: CGFloat? = 1.75
    /// How much of the path's length to draw, from its start: the cube timer
    /// starts at top centre and runs clockwise.
    var trim: Double = 1
    var cap: CGLineCap = .round
    var join: CGLineJoin = .round

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / box.width, rect.height / box.height)
        let dx = rect.midX - box.midX * scale
        let dy = rect.midY - box.midY * scale
        func pt(_ i: Int) -> CGPoint {
            CGPoint(x: dx + data[i] * scale, y: dy + data[i + 1] * scale)
        }
        var path = Path()
        var i = 0
        while i < data.count {
            switch Int(data[i]) {
            case 0:
                path.move(to: pt(i + 1))
                i += 3
            case 1:
                path.addLine(to: pt(i + 1))
                i += 3
            case 2:
                path.addCurve(to: pt(i + 5), control1: pt(i + 1), control2: pt(i + 3))
                i += 7
            default:
                path.closeSubpath()
                i += 1
            }
        }
        guard let lineWidth = lineWidth else { return path }
        let shown = min(max(trim, 0), 1)
        if shown <= 0 { return Path() }
        let line = shown < 1 ? path.trimmedPath(from: 0, to: CGFloat(shown)) : path
        return line.strokedPath(
            StrokeStyle(lineWidth: lineWidth * scale, lineCap: cap, lineJoin: join)
        )
    }
}

/// A pack glyph in one colour, as `Ic` draws it in the app.
struct AqGlyphView: View {
    let glyph: AqGlyph
    var color: Color
    /// Time left, `0...1`, for a timer layer. Every other layer ignores it.
    var progress: Double = 1

    var body: some View {
        ZStack {
            ForEach(glyph.layers.indices, id: \.self) { index in
                let layer = glyph.layers[index]
                if layer.paint {
                    AqPathShape(data: layer.path, lineWidth: nil).fill(color)
                }
                AqPathShape(data: layer.path, trim: layer.timer ? progress : 1)
                    .fill(color)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The session's own timer: aq_cube_session trimmed to the time left, over
/// aq_cube_frozen at 26% (the design's SessionCube).
///
/// It is drawn from the last state the app pushed — a melt stage, a freeze —
/// and never ticks on its own; the clock beside it does that for free. Trimmed
/// with SwiftUI rather than an SF Symbol's Variable Draw, so it is the same
/// picture on every OS this extension supports and needs no symbol catalog.
struct SessionCube: View {
    /// Time left, `0...1`.
    var left: Double
    var color: Color

    var body: some View {
        ZStack {
            AqGlyphView(glyph: .cubeFrozen, color: color)
                .opacity(0.26)
            AqGlyphView(glyph: .cubeSession, color: color, progress: left)
        }
    }
}

/// The pack's colour art, painted as the SVG paints it.
struct AqArtView: View {
    let art: AqArt

    var body: some View {
        ZStack {
            ForEach(art.layers.indices, id: \.self) { index in
                let layer = art.layers[index]
                if let fill = layer.fill {
                    AqPathShape(data: layer.path, box: art.box, lineWidth: nil)
                        .fill(Color(aqRGB: fill).opacity(layer.fillOpacity))
                }
                if let stroke = layer.stroke {
                    AqPathShape(
                        data: layer.path,
                        box: art.box,
                        lineWidth: layer.strokeWidth,
                        cap: layer.roundCap ? .round : .butt,
                        join: layer.roundJoin ? .round : .miter
                    )
                    .fill(Color(aqRGB: stroke).opacity(layer.strokeOpacity))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// BEGIN GENERATED by tool/generate_ambient_glyphs.js — do not edit by hand.
// Source: prototypes/v11/aq-icons.js (AQ.ICONS, AQ.adaColor, AQ.adaPose) and
// prototypes/v11/app.jsx (PRISM_MARK, MOOD_EXPR). Path data is the pack's 0 = move,
// 1 = line, 2 = cubic, 3 = close op list, in each design box, as in aq_glyphs.g.dart.

extension AqGlyph {
    /// `cube_frozen`: Not started.
    static let cubeFrozen = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p0),
        AqGlyphLayer(path: AqPathData.p1),
    ])

    /// `cube_session`: In session, time left.
    static let cubeSession = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p2, timer: true),
        AqGlyphLayer(path: AqPathData.p1),
    ])

    /// `cube_done`: Done.
    static let cubeDone = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p3),
        AqGlyphLayer(path: AqPathData.p4),
    ])

    /// `freeze`: App freeze.
    static let freeze = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p5),
        AqGlyphLayer(path: AqPathData.p6),
    ])

    /// `play`: Play.
    static let play = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p7),
    ])

    /// `end`: End session.
    static let end = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p8),
    ])

    /// `state_focus`: Focus.
    static let stateFocus = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p9),
        AqGlyphLayer(path: AqPathData.p10),
        AqGlyphLayer(path: AqPathData.p11),
    ])

    /// `state_deep_focus`: Deep Focus.
    static let stateDeepFocus = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p12),
        AqGlyphLayer(path: AqPathData.p13, paint: true),
    ])

    /// `state_creative`: Creative.
    static let stateCreative = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p14),
        AqGlyphLayer(path: AqPathData.p15),
    ])

    /// `state_relax`: Relax.
    static let stateRelax = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p16),
        AqGlyphLayer(path: AqPathData.p17),
    ])

    /// `mute`: Sound off.
    static let mute = AqGlyph(layers: [
        AqGlyphLayer(path: AqPathData.p18),
        AqGlyphLayer(path: AqPathData.p19),
    ])

    /// A Prism mode's mark, by the mode's name (app.jsx PRISM_MARK).
    static let prismMarks: [String: AqGlyph] = [
        "Deep Work": .stateDeepFocus,
        "Flow": .stateFocus,
        "Review": .stateCreative,
        "Wind-down": .stateRelax,
        "No sound": .mute,
    ]
}

extension AqArt {
    /// `aq_brand_ada`: Ada, full colour, in her fixed brand colours (AQ.adaColor).
    static let brandAda = AqArt(box: CGRect(x: 6, y: 4, width: 48, height: 48), layers: [
        AqArtLayer(path: AqPathData.p20, fill: 0xCBBCFD, stroke: 0x5A44F1, strokeWidth: 3.4, roundJoin: true),
        AqArtLayer(path: AqPathData.p21, fill: 0xFFFFFF, fillOpacity: 0.32),
        AqArtLayer(path: AqPathData.p22, stroke: 0xFFFFFF, strokeWidth: 2.4, strokeOpacity: 0.5, roundCap: true),
        AqArtLayer(path: AqPathData.p23, fill: 0xFFFFFF, fillOpacity: 0.85),
        AqArtLayer(path: AqPathData.p24, fill: 0xFFFFFF, fillOpacity: 0.7),
        AqArtLayer(path: AqPathData.p25, fill: 0xFFFFFF, fillOpacity: 0.55),
        AqArtLayer(path: AqPathData.p26, stroke: 0x31237C, strokeWidth: 2.1, roundCap: true),
        AqArtLayer(path: AqPathData.p27, fill: 0x31237C),
        AqArtLayer(path: AqPathData.p28, fill: 0xE8607F),
    ])

    /// The week row's mood cubes, 0 Rough … 4 Great: AQ.adaPose with tone idx,
    /// melt (4 - idx) / 4 and MOOD_EXPR[idx], without bubbles (MoodWeekRow).
    static let moods: [AqArt] = [
        AqArt(box: CGRect(x: 2, y: 2, width: 56, height: 56), layers: [
            AqArtLayer(path: AqPathData.p29, fill: 0xEAE8F2, stroke: 0xA79FC4, strokeWidth: 2.2, roundJoin: true),
            AqArtLayer(path: AqPathData.p30, fill: 0xFFFFFF, fillOpacity: 0.16),
            AqArtLayer(path: AqPathData.p31, stroke: 0xFFFFFF, strokeWidth: 2.4, strokeOpacity: 0.22, roundCap: true),
            AqArtLayer(path: AqPathData.p32, stroke: 0x938EAC, strokeWidth: 2, roundCap: true),
            AqArtLayer(path: AqPathData.p33, stroke: 0x938EAC, strokeWidth: 2, roundCap: true),
        ]),
        AqArt(box: CGRect(x: 2, y: 2, width: 56, height: 56), layers: [
            AqArtLayer(path: AqPathData.p34, fill: 0xE4DDF3, stroke: 0x9286D2, strokeWidth: 2.5, roundJoin: true),
            AqArtLayer(path: AqPathData.p35, fill: 0xFFFFFF, fillOpacity: 0.2),
            AqArtLayer(path: AqPathData.p36, stroke: 0xFFFFFF, strokeWidth: 2.4, strokeOpacity: 0.29, roundCap: true),
            AqArtLayer(path: AqPathData.p37, fill: 0x787299),
            AqArtLayer(path: AqPathData.p38, fill: 0x787299),
            AqArtLayer(path: AqPathData.p39, stroke: 0x787299, strokeWidth: 2.1, roundCap: true),
        ]),
        AqArt(box: CGRect(x: 2, y: 2, width: 56, height: 56), layers: [
            AqArtLayer(path: AqPathData.p40, fill: 0xDCD3F7, stroke: 0x7D70D9, strokeWidth: 2.8, roundJoin: true),
            AqArtLayer(path: AqPathData.p41, fill: 0xFFFFFF, fillOpacity: 0.24),
            AqArtLayer(path: AqPathData.p42, stroke: 0xFFFFFF, strokeWidth: 2.4, strokeOpacity: 0.36, roundCap: true),
            AqArtLayer(path: AqPathData.p43, fill: 0x5C5499),
            AqArtLayer(path: AqPathData.p44, fill: 0x5C5499),
            AqArtLayer(path: AqPathData.p45, stroke: 0x5C5499, strokeWidth: 2.2, roundCap: true),
        ]),
        AqArt(box: CGRect(x: 2, y: 2, width: 56, height: 56), layers: [
            AqArtLayer(path: AqPathData.p46, fill: 0xD2C5FA, stroke: 0x6A5CE4, strokeWidth: 3.1, roundJoin: true),
            AqArtLayer(path: AqPathData.p47, fill: 0xFFFFFF, fillOpacity: 0.28),
            AqArtLayer(path: AqPathData.p48, stroke: 0xFFFFFF, strokeWidth: 2.4, strokeOpacity: 0.43, roundCap: true),
            AqArtLayer(path: AqPathData.p49, fill: 0x41358F),
            AqArtLayer(path: AqPathData.p50, fill: 0x41358F),
            AqArtLayer(path: AqPathData.p51, stroke: 0x41358F, strokeWidth: 2.3, roundCap: true),
        ]),
        AqArt(box: CGRect(x: 2, y: 2, width: 56, height: 56), layers: [
            AqArtLayer(path: AqPathData.p20, fill: 0xCBBCFD, stroke: 0x5A44F1, strokeWidth: 3.4, roundJoin: true),
            AqArtLayer(path: AqPathData.p21, fill: 0xFFFFFF, fillOpacity: 0.32),
            AqArtLayer(path: AqPathData.p22, stroke: 0xFFFFFF, strokeWidth: 2.4, strokeOpacity: 0.5, roundCap: true),
            AqArtLayer(path: AqPathData.p26, stroke: 0x31237C, strokeWidth: 2.1, roundCap: true),
            AqArtLayer(path: AqPathData.p27, fill: 0x31237C),
            AqArtLayer(path: AqPathData.p28, fill: 0xE8607F),
        ]),
    ]
}

enum AqPathData {
    static let p0: [CGFloat] = [0, 12, 3, 1, 14.6, 3, 2, 16.84, 3, 17.96, 3, 18.82, 3.44, 2, 19.574, 3.824, 20.186, 4.436, 20.57, 5.19, 2, 21.01, 6.05, 21.01, 7.17, 21.01, 9.41, 1, 21.01, 14.6, 2, 21.01, 16.84, 21.01, 17.96, 20.57, 18.82, 2, 20.186, 19.574, 19.574, 20.186, 18.82, 20.57, 2, 17.96, 21.01, 16.84, 21.01, 14.6, 21.01, 1, 9.4, 21.01, 2, 7.16, 21.01, 6.04, 21.01, 5.18, 20.57, 2, 4.426, 20.186, 3.814, 19.574, 3.43, 18.82, 2, 2.99, 17.96, 2.99, 16.84, 2.99, 14.6, 1, 2.99, 9.4, 2, 2.99, 7.16, 2.99, 6.04, 3.43, 5.18, 2, 3.814, 4.426, 4.426, 3.814, 5.18, 3.43, 2, 6.04, 2.99, 7.16, 2.99, 9.4, 2.99, 3]
    static let p1: [CGFloat] = [0, 7, 11.5, 1, 7, 9.4, 2, 7, 8.07, 8.07, 7, 9.4, 7, 1, 10.75, 7]
    static let p2: [CGFloat] = [0, 12, 3, 1, 14.6, 3, 2, 16.84, 3, 17.96, 3, 18.82, 3.44, 2, 19.574, 3.824, 20.186, 4.436, 20.57, 5.19, 2, 21.01, 6.05, 21.01, 7.17, 21.01, 9.41, 1, 21.01, 14.6, 2, 21.01, 16.84, 21.01, 17.96, 20.57, 18.82, 2, 20.186, 19.574, 19.574, 20.186, 18.82, 20.57, 2, 17.96, 21.01, 16.84, 21.01, 14.6, 21.01, 1, 9.4, 21.01, 2, 7.16, 21.01, 6.04, 21.01, 5.18, 20.57, 2, 4.426, 20.186, 3.814, 19.574, 3.43, 18.82, 2, 2.99, 17.96, 2.99, 16.84, 2.99, 14.6, 1, 2.99, 9.4, 2, 2.99, 7.16, 2.99, 6.04, 3.43, 5.18, 2, 3.814, 4.426, 4.426, 3.814, 5.18, 3.43, 2, 6.04, 2.99, 7.16, 2.99, 9.4, 2.99, 1, 12, 3, 3]
    static let p3: [CGFloat] = [0, 12, 2.9, 2, 10.2, 5.4, 5.5, 10, 5.5, 14.5, 2, 5.5, 18.09, 8.41, 21, 12, 21, 2, 15.59, 21, 18.5, 18.09, 18.5, 14.5, 2, 18.5, 10, 13.8, 5.4, 12, 2.9, 3]
    static let p4: [CGFloat] = [0, 9, 14.5, 2, 9, 16.157, 10.343, 17.5, 12, 17.5]
    static let p5: [CGFloat] = [0, 12, 3, 1, 12, 21, 0, 19.79, 7.5, 1, 4.21, 16.5, 0, 19.79, 16.5, 1, 4.21, 7.5]
    static let p6: [CGFloat] = [0, 10.23, 4.23, 1, 12, 6, 1, 13.77, 4.23, 0, 17.84, 6.59, 1, 17.2, 9, 1, 19.61, 9.65, 0, 19.61, 14.35, 1, 17.2, 15, 1, 17.84, 17.41, 0, 13.77, 19.77, 1, 12, 18, 1, 10.23, 19.77, 0, 6.16, 17.41, 1, 6.8, 15, 1, 4.39, 14.35, 0, 4.39, 9.65, 1, 6.8, 9, 1, 6.16, 6.59]
    static let p7: [CGFloat] = [0, 8.5, 5.5, 1, 8.5, 18.5, 1, 19, 12, 3]
    static let p8: [CGFloat] = [0, 12, 6, 1, 13.2, 6, 2, 14.88, 6, 15.72, 6, 16.36, 6.33, 2, 16.924, 6.618, 17.382, 7.076, 17.67, 7.64, 2, 18, 8.28, 18, 9.12, 18, 10.8, 1, 18, 13.2, 2, 18, 14.88, 18, 15.72, 17.67, 16.36, 2, 17.382, 16.924, 16.924, 17.382, 16.36, 17.67, 2, 15.72, 18, 14.88, 18, 13.2, 18, 1, 10.8, 18, 2, 9.12, 18, 8.28, 18, 7.64, 17.67, 2, 7.076, 17.382, 6.618, 16.924, 6.33, 16.36, 2, 6, 15.72, 6, 14.88, 6, 13.2, 1, 6, 10.8, 2, 6, 9.12, 6, 8.28, 6.33, 7.64, 2, 6.618, 7.076, 7.076, 6.618, 7.64, 6.33, 2, 8.28, 6, 9.12, 6, 10.8, 6, 3]
    static let p9: [CGFloat] = [0, 18.36, 5.64, 2, 21.241, 8.521, 21.827, 12.977, 19.79, 16.505, 2, 17.753, 20.033, 13.6, 21.752, 9.665, 20.697, 2, 5.731, 19.642, 2.995, 16.076, 2.996, 12.002, 2, 2.997, 7.928, 5.735, 4.363, 9.67, 3.31]
    static let p10: [CGFloat] = [0, 7.93, 16.07, 2, 6.088, 14.232, 5.709, 11.387, 7.007, 9.131, 2, 8.305, 6.876, 10.955, 5.773, 13.47, 6.442, 2, 15.984, 7.112, 17.736, 9.386, 17.741, 11.988, 2, 17.745, 14.591, 16.002, 16.871, 13.49, 17.55]
    static let p11: [CGFloat] = [0, 12, 11.4, 2, 12.214, 11.4, 12.412, 11.514, 12.52, 11.7, 2, 12.627, 11.886, 12.627, 12.114, 12.52, 12.3, 2, 12.412, 12.486, 12.214, 12.6, 12, 12.6, 2, 11.786, 12.6, 11.588, 12.486, 11.48, 12.3, 2, 11.373, 12.114, 11.373, 11.886, 11.48, 11.7, 2, 11.588, 11.514, 11.786, 11.4, 12, 11.4, 3]
    static let p12: [CGFloat] = [0, 12, 3, 2, 16.971, 3, 21, 7.029, 21, 12, 2, 21, 16.971, 16.971, 21, 12, 21, 2, 7.029, 21, 3, 16.971, 3, 12, 2, 3, 7.029, 7.029, 3, 12, 3, 3]
    static let p13: [CGFloat] = [0, 12, 8, 2, 14.209, 8, 16, 9.791, 16, 12, 2, 16, 14.209, 14.209, 16, 12, 16, 2, 9.791, 16, 8, 14.209, 8, 12, 2, 8, 9.791, 9.791, 8, 12, 8, 3]
    static let p14: [CGFloat] = [0, 16, 5.07, 2, 16.483, 5.349, 16.935, 5.677, 17.35, 6.05, 0, 19.31, 8.75, 2, 19.538, 9.26, 19.713, 9.793, 19.83, 10.34, 0, 19.83, 13.66, 2, 19.713, 14.207, 19.538, 14.74, 19.31, 15.25, 0, 12.84, 19.96, 2, 12.282, 20.019, 11.718, 20.019, 11.16, 19.96, 0, 8, 18.93, 2, 7.517, 18.651, 7.065, 18.323, 6.65, 17.95, 0, 4.17, 10.34, 2, 4.287, 9.793, 4.462, 9.26, 4.69, 8.75, 0, 6.65, 6.05, 2, 7.065, 5.677, 7.517, 5.349, 8, 5.07]
    static let p15: [CGFloat] = [0, 12, 2.9, 2, 12.393, 2.9, 12.756, 3.11, 12.953, 3.45, 2, 13.149, 3.79, 13.149, 4.21, 12.953, 4.55, 2, 12.756, 4.89, 12.393, 5.1, 12, 5.1, 2, 11.607, 5.1, 11.244, 4.89, 11.047, 4.55, 2, 10.851, 4.21, 10.851, 3.79, 11.047, 3.45, 2, 11.244, 3.11, 11.607, 2.9, 12, 2.9, 3, 0, 16.7, 17.37, 2, 17.093, 17.37, 17.456, 17.58, 17.653, 17.92, 2, 17.849, 18.26, 17.849, 18.68, 17.653, 19.02, 2, 17.456, 19.36, 17.093, 19.57, 16.7, 19.57, 2, 16.307, 19.57, 15.944, 19.36, 15.747, 19.02, 2, 15.551, 18.68, 15.551, 18.26, 15.747, 17.92, 2, 15.944, 17.58, 16.307, 17.37, 16.7, 17.37, 3, 0, 4.39, 13.37, 2, 4.998, 13.37, 5.49, 13.862, 5.49, 14.47, 2, 5.49, 15.078, 4.998, 15.57, 4.39, 15.57, 2, 3.782, 15.57, 3.29, 15.078, 3.29, 14.47, 2, 3.29, 13.862, 3.782, 13.37, 4.39, 13.37, 3]
    static let p16: [CGFloat] = [0, 3, 9, 2, 6, 7, 9, 7, 12, 9, 2, 15, 11, 18, 11, 21, 9]
    static let p17: [CGFloat] = [0, 3, 15, 2, 6, 13, 9, 13, 12, 15, 2, 15, 17, 18, 17, 21, 15]
    static let p18: [CGFloat] = [0, 4, 9.5, 1, 7.5, 9.5, 1, 12, 5.5, 1, 12, 18.5, 1, 7.5, 14.5, 1, 4, 14.5, 3]
    static let p19: [CGFloat] = [0, 15.5, 9.5, 1, 20.5, 14.5, 0, 20.5, 9.5, 1, 15.5, 14.5]
    static let p20: [CGFloat] = [0, 20, 8, 1, 40, 8, 2, 46, 8, 49, 11, 49, 17, 1, 49, 41, 2, 49, 47, 46, 50, 40, 50, 2, 33.333, 50, 26.667, 50, 20, 50, 2, 14, 50, 11, 47, 11, 41, 1, 11, 17, 2, 11, 11, 14, 8, 20, 8, 3]
    static let p21: [CGFloat] = [0, 20.95, 13, 1, 39.05, 13, 2, 42.35, 13, 44, 14.65, 44, 17.95, 1, 44, 39.6, 2, 44, 43.2, 42.2, 45, 38.6, 45, 2, 32.867, 45, 27.133, 45, 21.4, 45, 2, 17.8, 45, 16, 43.2, 16, 39.6, 1, 16, 17.95, 2, 16, 14.65, 17.65, 13, 20.95, 13, 3]
    static let p22: [CGFloat] = [0, 21, 10.5, 2, 16.333, 10.833, 14.067, 14.667, 14.2, 22]
    static let p23: [CGFloat] = [0, 18.3, 17, 2, 18.3, 17.965, 18.815, 18.856, 19.65, 19.338, 2, 20.485, 19.821, 21.515, 19.821, 22.35, 19.338, 2, 23.185, 18.856, 23.7, 17.965, 23.7, 17, 2, 23.7, 16.035, 23.185, 15.144, 22.35, 14.662, 2, 21.515, 14.179, 20.485, 14.179, 19.65, 14.662, 2, 18.815, 15.144, 18.3, 16.035, 18.3, 17, 3]
    static let p24: [CGFloat] = [0, 25, 14, 2, 25, 14.828, 25.672, 15.5, 26.5, 15.5, 2, 27.328, 15.5, 28, 14.828, 28, 14, 2, 28, 13.172, 27.328, 12.5, 26.5, 12.5, 2, 25.672, 12.5, 25, 13.172, 25, 14, 3]
    static let p25: [CGFloat] = [0, 17.6, 23.5, 2, 17.6, 24.179, 17.962, 24.806, 18.55, 25.145, 2, 19.138, 25.485, 19.862, 25.485, 20.45, 25.145, 2, 21.038, 24.806, 21.4, 24.179, 21.4, 23.5, 2, 21.4, 22.821, 21.038, 22.194, 20.45, 21.855, 2, 19.862, 21.515, 19.138, 21.515, 18.55, 21.855, 2, 17.962, 22.194, 17.6, 22.821, 17.6, 23.5, 3]
    static let p26: [CGFloat] = [0, 21, 29.2, 2, 23, 26.4, 25, 26.4, 27, 29.2, 0, 33, 29.2, 2, 35, 26.4, 37, 26.4, 39, 29.2]
    static let p27: [CGFloat] = [0, 23.5, 34, 2, 27.833, 40.333, 32.167, 40.333, 36.5, 34, 2, 32.167, 35.667, 27.833, 35.667, 23.5, 34, 3]
    static let p28: [CGFloat] = [0, 26.7, 38.4, 2, 28.9, 40.4, 31.1, 40.4, 33.3, 38.4, 2, 31.1, 39.467, 28.9, 39.467, 26.7, 38.4, 3]
    static let p29: [CGFloat] = [0, 30, 23, 1, 30, 23, 2, 38, 23, 42, 27, 42, 35, 1, 55, 30, 2, 55, 44.667, 47.667, 52, 33, 52, 2, 31, 53.667, 29, 53.667, 27, 52, 2, 12.333, 52, 5, 44.667, 5, 30, 1, 18, 35, 2, 18, 27, 22, 23, 30, 23, 3]
    static let p30: [CGFloat] = [0, 29.6, 28, 1, 30.4, 28, 2, 34.8, 28, 37, 30.2, 37, 34.6, 1, 50, 33.8, 2, 50, 42.6, 45.6, 47, 36.8, 47, 2, 32.267, 48, 27.733, 48, 23.2, 47, 2, 14.4, 47, 10, 42.6, 10, 33.8, 1, 23, 34.6, 2, 23, 30.2, 25.2, 28, 29.6, 28, 3]
    static let p31: [CGFloat] = [0, 31, 25.5, 2, 24.333, 25.833, 21.067, 30.667, 21.2, 40]
    static let p32: [CGFloat] = [0, 22.7, 35, 1, 27.7, 38, 0, 37.3, 35, 1, 32.3, 38]
    static let p33: [CGFloat] = [0, 23, 46.5, 2, 27.667, 42.167, 32.333, 42.167, 37, 46.5]
    static let p34: [CGFloat] = [0, 27.5, 19.25, 1, 32.5, 19.25, 2, 40, 19.25, 43.75, 23, 43.75, 30.5, 1, 53.5, 32.75, 2, 53.5, 45.25, 47.25, 51.5, 34.75, 51.5, 2, 31.583, 52.753, 28.417, 52.753, 25.25, 51.5, 2, 12.75, 51.5, 6.5, 45.25, 6.5, 32.75, 1, 16.25, 30.5, 2, 16.25, 23, 20, 19.25, 27.5, 19.25, 3]
    static let p35: [CGFloat] = [0, 27.44, 24.25, 1, 32.56, 24.25, 2, 36.687, 24.25, 38.75, 26.313, 38.75, 30.44, 1, 48.5, 35.25, 2, 48.5, 42.75, 44.75, 46.5, 37.25, 46.5, 2, 32.417, 47.253, 27.583, 47.253, 22.75, 46.5, 2, 15.25, 46.5, 11.5, 42.75, 11.5, 35.25, 1, 21.25, 30.44, 2, 21.25, 26.313, 23.313, 24.25, 27.44, 24.25, 3]
    static let p36: [CGFloat] = [0, 28.5, 21.75, 2, 22.333, 22.083, 19.317, 26.667, 19.45, 35.5]
    static let p37: [CGFloat] = [0, 22.57, 34.38, 2, 22.57, 35.212, 23.014, 35.982, 23.735, 36.398, 2, 24.456, 36.814, 25.344, 36.814, 26.065, 36.398, 2, 26.786, 35.982, 27.23, 35.212, 27.23, 34.38, 2, 27.23, 33.548, 26.786, 32.778, 26.065, 32.362, 2, 25.344, 31.946, 24.456, 31.946, 23.735, 32.362, 2, 23.014, 32.778, 22.57, 33.548, 22.57, 34.38, 3]
    static let p38: [CGFloat] = [0, 32.77, 34.38, 2, 32.77, 35.212, 33.214, 35.982, 33.935, 36.398, 2, 34.656, 36.814, 35.544, 36.814, 36.265, 36.398, 2, 36.986, 35.982, 37.43, 35.212, 37.43, 34.38, 2, 37.43, 33.548, 36.986, 32.778, 36.265, 32.362, 2, 35.544, 31.946, 34.656, 31.946, 33.935, 32.362, 2, 33.214, 32.778, 32.77, 33.548, 32.77, 34.38, 3]
    static let p39: [CGFloat] = [0, 24, 43.38, 2, 28, 40.713, 32, 40.713, 36, 43.38]
    static let p40: [CGFloat] = [0, 25, 15.5, 1, 35, 15.5, 2, 42, 15.5, 45.5, 19, 45.5, 26, 1, 52, 35.5, 2, 52, 45.833, 46.833, 51, 36.5, 51, 2, 32.167, 51.833, 27.833, 51.833, 23.5, 51, 2, 13.167, 51, 8, 45.833, 8, 35.5, 1, 14.5, 26, 2, 14.5, 19, 18, 15.5, 25, 15.5, 3]
    static let p41: [CGFloat] = [0, 25.28, 20.5, 1, 34.73, 20.5, 2, 38.577, 20.5, 40.5, 22.427, 40.5, 26.28, 1, 47, 36.7, 2, 47, 42.9, 43.9, 46, 37.7, 46, 2, 32.567, 46.5, 27.433, 46.5, 22.3, 46, 2, 16.1, 46, 13, 42.9, 13, 36.7, 1, 19.5, 26.28, 2, 19.5, 22.427, 21.427, 20.5, 25.28, 20.5, 3]
    static let p42: [CGFloat] = [0, 26, 18, 2, 20.333, 18.333, 17.567, 22.667, 17.7, 31]
    static let p43: [CGFloat] = [0, 22.15, 32.25, 2, 22.15, 33.125, 22.617, 33.934, 23.375, 34.372, 2, 24.133, 34.809, 25.067, 34.809, 25.825, 34.372, 2, 26.583, 33.934, 27.05, 33.125, 27.05, 32.25, 2, 27.05, 31.375, 26.583, 30.566, 25.825, 30.128, 2, 25.067, 29.691, 24.133, 29.691, 23.375, 30.128, 2, 22.617, 30.566, 22.15, 31.375, 22.15, 32.25, 3]
    static let p44: [CGFloat] = [0, 32.95, 32.25, 2, 32.95, 33.603, 34.047, 34.7, 35.4, 34.7, 2, 36.753, 34.7, 37.85, 33.603, 37.85, 32.25, 2, 37.85, 30.897, 36.753, 29.8, 35.4, 29.8, 2, 34.047, 29.8, 32.95, 30.897, 32.95, 32.25, 3]
    static let p45: [CGFloat] = [0, 24, 39.25, 1, 36, 39.25]
    static let p46: [CGFloat] = [0, 22.5, 11.75, 1, 37.5, 11.75, 2, 44, 11.75, 47.25, 15, 47.25, 21.5, 1, 50.5, 38.25, 2, 50.5, 46.417, 46.417, 50.5, 38.25, 50.5, 2, 32.75, 50.92, 27.25, 50.92, 21.75, 50.5, 2, 13.583, 50.5, 9.5, 46.417, 9.5, 38.25, 1, 12.75, 21.5, 2, 12.75, 15, 16, 11.75, 22.5, 11.75, 3]
    static let p47: [CGFloat] = [0, 23.11, 16.75, 1, 36.89, 16.75, 2, 40.463, 16.75, 42.25, 18.537, 42.25, 22.11, 1, 45.5, 38.15, 2, 45.5, 43.05, 43.05, 45.5, 38.15, 45.5, 2, 32.717, 45.753, 27.283, 45.753, 21.85, 45.5, 2, 16.95, 45.5, 14.5, 43.05, 14.5, 38.15, 1, 17.75, 22.11, 2, 17.75, 18.537, 19.537, 16.75, 23.11, 16.75, 3]
    static let p48: [CGFloat] = [0, 23.5, 14.25, 2, 18.333, 14.583, 15.817, 18.667, 15.95, 26.5]
    static let p49: [CGFloat] = [0, 21.72, 30.13, 2, 21.72, 31.555, 22.875, 32.71, 24.3, 32.71, 2, 25.725, 32.71, 26.88, 31.555, 26.88, 30.13, 2, 26.88, 28.705, 25.725, 27.55, 24.3, 27.55, 2, 22.875, 27.55, 21.72, 28.705, 21.72, 30.13, 3]
    static let p50: [CGFloat] = [0, 33.12, 30.13, 2, 33.12, 31.052, 33.612, 31.903, 34.41, 32.364, 2, 35.208, 32.825, 36.192, 32.825, 36.99, 32.364, 2, 37.788, 31.903, 38.28, 31.052, 38.28, 30.13, 2, 38.28, 29.208, 37.788, 28.357, 36.99, 27.896, 2, 36.192, 27.435, 35.208, 27.435, 34.41, 27.896, 2, 33.612, 28.357, 33.12, 29.208, 33.12, 30.13, 3]
    static let p51: [CGFloat] = [0, 24, 37.13, 2, 28, 40.13, 32, 40.13, 36, 37.13]
}
// END GENERATED by tool/generate_ambient_glyphs.js
