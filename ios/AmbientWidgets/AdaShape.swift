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
