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

/// Ada at a melt stage, with the face and the frost the state calls for.
///
/// Sized down to 22pt in the minimal Island and masked to one flat colour in a
/// status bar, so everything here has to survive losing colour and detail: the
/// silhouette carries the meaning, the fills only decorate it.
struct AdaView: View {
    /// `0..<kMeltStages`, straight from the shared state.
    var stage: Int

    /// Frost, not a pause glyph: she stops mid-melt and changes state of matter.
    var frozen: Bool = false

    /// Draw the face. Dropped at small sizes, where it is noise rather than
    /// information.
    var showsFace: Bool = true

    private var melt: Double {
        // Five stages across a whole session (kMeltStages in Dart).
        Double(min(max(stage, 0), 4)) / 4
    }

    private var body_: Color { frozen ? Color(red: 0.84, green: 0.93, blue: 0.97)
                                      : Color(red: 0.82, green: 0.77, blue: 0.98) }
    private var stroke: Color { frozen ? Color(red: 0.62, green: 0.84, blue: 0.94)
                                       : Color(red: 0.42, green: 0.36, blue: 0.89) }
    private var ink: Color { frozen ? Color(red: 0.25, green: 0.43, blue: 0.52)
                                    : Color(red: 0.19, green: 0.14, blue: 0.49) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let unit = side / 60

            ZStack {
                AdaShape(melt: melt)
                    .fill(body_)
                AdaShape(melt: melt)
                    .stroke(stroke, lineWidth: max(1, (3.4 - 1.2 * melt) * unit))

                if frozen {
                    // Frost spurs. At 22pt these, not the hue, are what say
                    // "held" — colour is the first thing an Always-On display
                    // takes away.
                    FrostSpurs()
                        .stroke(stroke, style: StrokeStyle(lineWidth: max(1, 1.5 * unit),
                                                           lineCap: .round))
                }

                if showsFace {
                    face(unit: unit)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    /// Eyes and mouth, on the same interpolation as the painter: the eyes
    /// shrink and converge as she goes, and the face is held until she is spent.
    private func face(unit: CGFloat) -> some View {
        let m = melt
        let tY = 8 + 15 * m
        let bY = 50 + 2 * m
        let faceCY = (tY + bY) / 2 + 1
        let eyeY = faceCY - 2
        let eyeR = 2.7 - 0.5 * m
        let eyeDX = 6 - 1.2 * m
        let mouthY = faceCY + 5

        return ZStack {
            Circle()
                .fill(ink)
                .frame(width: eyeR * 2 * unit, height: eyeR * 2 * unit)
                .position(x: (30 - eyeDX) * unit, y: eyeY * unit)
            Circle()
                .fill(ink)
                .frame(width: eyeR * 2 * unit, height: eyeR * 2 * unit)
                .position(x: (30 + eyeDX) * unit, y: eyeY * unit)

            Path { path in
                path.move(to: CGPoint(x: (30 - 4.5) * unit, y: mouthY * unit))
                if frozen {
                    // Held: a level line, not a smile.
                    path.addLine(to: CGPoint(x: (30 + 4.5) * unit, y: mouthY * unit))
                } else {
                    path.addQuadCurve(
                        to: CGPoint(x: (30 + 4.5) * unit, y: mouthY * unit),
                        control: CGPoint(x: 30 * unit, y: (mouthY + 3.2) * unit)
                    )
                }
            }
            .stroke(ink, style: StrokeStyle(lineWidth: max(1, 1.7 * unit), lineCap: .round))
        }
        .frame(width: 60 * unit, height: 60 * unit)
    }
}

/// The eight spurs that say frozen from across a desk.
private struct FrostSpurs: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 60
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
        }
        var path = Path()
        let spurs: [(Double, Double, Double, Double)] = [
            (30, 3, 30, 12), (30, 48, 30, 57),
            (3, 30, 12, 30), (48, 30, 57, 30),
            (11, 11, 17, 17), (49, 11, 43, 17),
            (11, 49, 17, 43), (49, 49, 43, 43),
        ]
        for (x1, y1, x2, y2) in spurs {
            path.move(to: p(x1, y1))
            path.addLine(to: p(x2, y2))
        }
        return path
    }
}
