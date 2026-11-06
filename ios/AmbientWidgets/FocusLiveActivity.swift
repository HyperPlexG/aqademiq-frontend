import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

#if canImport(ActivityKit)
import ActivityKit

/// The session, everywhere iOS will draw it.
///
/// One activity, four presentations: the lock-screen card, and the Island's
/// compact, minimal and expanded forms. All of them read the same state, and
/// none of them is ever told the time — `Text(timerInterval:)` counts down from
/// `endsAt` on its own, which is what makes a whole session cost five updates.
///
/// v11 (04-B · Ambient surfaces): aq_cube_session is the timer — the cube
/// trimmed to the time left, over aq_cube_frozen at 26% — wherever Ada used to
/// melt. Ice is pinned: --aq-ice on light grounds, --aq-ice-on-dark on black.
/// The lock-screen card follows Light / Dark; the Island and StandBy are black
/// in both.
@available(iOS 16.1, *)
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color.laPlatform)
                .activitySystemActionForegroundColor(Color.laPlatformInk)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — a long press. The task title is the point: a
                // student who long-presses at minute forty has usually
                // forgotten what they sat down to do.
                //
                // Split across regions rather than stacked in .bottom: .bottom
                // is only the strip below the sensor housing, and a whole card
                // in it runs out of room and is clipped from the base — which
                // took the buttons with it. .leading and .trailing are the
                // space beside the housing; .center is the full width between
                // them, so the title gets the room the design gives it.
                DynamicIslandExpandedRegion(.leading) {
                    StateCube(state: context.state, color: AqColor.iceOnDark)
                        .frame(width: 46, height: 46)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(taskTitle(context))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let subtitle = subtitle(for: context) {
                            Text(subtitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.64))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // A definite width, not maxWidth: .infinity. The side regions
                // are sized from their content's ideal width, and a timer text
                // with an infinite frame has no ideal width to offer — so once
                // .center claimed the spare room the clock was left about 40pt
                // and rendered as "24…". 92pt holds "24:58" at 28pt, with the
                // scale factor kept for the rare hour-long session.
                DynamicIslandExpandedRegion(.trailing) {
                    TimeReadout(state: context.state, size: 28,
                                ink: .white, ice: AqColor.iceOnDark,
                                width: 92, alignment: .trailing)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        LaRail(spent: 1 - context.state.left,
                               frozen: context.state.frozen,
                               ice: AqColor.iceOnDark,
                               track: .white.opacity(0.14))

                        if #available(iOS 17.0, *) {
                            if !context.state.isDone {
                                SessionPills(frozen: context.state.frozen,
                                             endOnly: context.sessionIsStale)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // The cube leads, the clock trails. The cube is the only thing
                // here that ever changes on a push.
                StateCube(state: context.state, color: AqColor.iceOnDark)
                    .frame(width: 22, height: 22)
            } compactTrailing: {
                CompactTime(state: context.state)
            } minimal: {
                // Sharing the Island with another activity: a circle is all we
                // get, and the cube is legible at 21pt where a word is not.
                StateCube(state: context.state, color: AqColor.iceOnDark)
                    .frame(width: 21, height: 21)
            }
            .keylineTint(AqColor.iceOnDark)
        }
    }

    /// What the student sat down to do — or, when they started five minutes
    /// from a widget and there is no task at all, something true rather than an
    /// empty string. A blank title collapsed the middle column entirely and
    /// left the Island looking like a bug.
    private func taskTitle(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        FocusLiveActivity.title(context.attributes)
    }

    /// "CC 401 · Deep Work": the subject and what is sounding. Nil rather than
    /// "" when there is nothing to show, so the line is dropped, not left empty.
    private func subtitle(for context: ActivityViewContext<FocusActivityAttributes>) -> String? {
        let parts = [context.attributes.subjectLabel, context.state.prismMode]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func title(_ attributes: FocusActivityAttributes) -> String {
        let given = attributes.taskTitle.trimmingCharacters(in: .whitespaces)
        return given.isEmpty ? "Focus session" : given
    }
}

@available(iOS 16.1, *)
extension ActivityViewContext where Attributes == FocusActivityAttributes {
    /// A running session past its stale date — a minute after its end, with
    /// the app not there to end it (it was not running when the clock ran
    /// out). The clock already reads 0:00; what changes is that Freeze goes,
    /// since there is nothing left to hold, and End stays, so the card can
    /// still be cleared. Never while held or done: neither is given a stale
    /// date.
    var sessionIsStale: Bool {
        guard #available(iOS 16.2, *) else { return false }
        return isStale && !state.isDone && !state.frozen
    }
}

/// The countdown, or the held time.
///
/// The whole design rests on this one distinction: while running, the system
/// ticks `Text(timerInterval:)` for free and the app never wakes; while frozen,
/// a live timer would keep counting down a session that is not running, so it
/// is replaced by static text — in ice, as every frozen clock in v11 is.
/// Unhandled, that single detail makes the feature worse than not shipping it.
@available(iOS 16.1, *)
struct TimeReadout: View {
    let state: FocusActivityAttributes.ContentState
    var size: CGFloat
    var ink: Color
    var ice: Color
    /// A definite width where the clock shares a row: a timer text has no ideal
    /// width of its own and otherwise takes the whole row.
    var width: CGFloat? = nil
    var alignment: TextAlignment = .leading
    var tracking: CGFloat = 0

    var body: some View {
        Group {
            if state.isDone {
                // la-lock-done: what was spent, "25:00", never a clock.
                Text(state.focusedText)
                    .foregroundStyle(ink)
            } else if state.frozen {
                Text(staticRemaining)
                    .foregroundStyle(ice)
            } else {
                // Never a reversed range: a session whose end has just passed
                // reads 0:00 until the app ends the activity, rather than
                // trapping in the extension.
                Text(timerInterval: Date.now...max(state.endsAt, Date.now),
                     pauseTime: nil,
                     countsDown: true)
                    .foregroundStyle(ink)
            }
        }
        .font(.system(size: size, weight: .heavy).monospacedDigit())
        .tracking(tracking)
        .multilineTextAlignment(alignment)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: width, alignment: alignment == .trailing ? .trailing : .leading)
    }

    private var staticRemaining: String {
        let safe = max(0, state.remainingSec)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}

/// The session cube, or aq_cube_done once the session has run to its end.
@available(iOS 16.1, *)
struct StateCube: View {
    let state: FocusActivityAttributes.ContentState
    var color: Color

    var body: some View {
        if state.isDone {
            AqGlyphView(glyph: .cubeDone, color: color)
        } else {
            SessionCube(left: state.left, color: color)
        }
    }
}

/// The compact Island's clock: white while it runs; frozen, the ice glyph and
/// the held time in ice.
@available(iOS 16.1, *)
struct CompactTime: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            if state.frozen && !state.isDone {
                AqGlyphView(glyph: .freeze, color: AqColor.iceOnDark)
                    .frame(width: 14, height: 14)
            }
            TimeReadout(state: state, size: 15,
                        ink: .white, ice: AqColor.iceOnDark,
                        width: 48, alignment: .trailing)
        }
    }
}

/// "Deep Work", with its Prism mark — or "Frozen" with the ice glyph while held,
/// or "Session done" on its own once the session has run to its end.
@available(iOS 16.1, *)
struct ModeLabel: View {
    let frozen: Bool
    let mode: String?
    var color: Color
    var size: CGFloat
    var glyphSize: CGFloat
    var spacing: CGFloat = 5
    var done: Bool = false

    var body: some View {
        HStack(spacing: spacing) {
            if !done {
                AqGlyphView(glyph: glyph, color: color)
                    .frame(width: glyphSize, height: glyphSize)
            }
            Text(text)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private var text: String {
        if done { return "Session done" }
        if frozen { return "Frozen" }
        guard let mode = mode, !mode.isEmpty else { return "Focus" }
        return mode
    }

    private var glyph: AqGlyph {
        if frozen { return .freeze }
        return mode.flatMap { AqGlyph.prismMarks[$0] } ?? .stateFocus
    }
}

/// The lock-screen card (la-lock, la-lock-frozen, la-lock-done): the cube in
/// its well, what the session is, the task, the clock, and one press to freeze
/// or resume. Done, the well holds aq_cube_done, the clock reads the time spent
/// and there is nothing left to press.
@available(iOS 16.1, *)
struct LockScreenCard: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    @Environment(\.colorScheme) private var scheme

    /// Always-On and StandBy's night mode both dim the panel. Colour is the
    /// first thing they take, which is why frozen has to stay distinguishable
    /// by more than hue: the glyph, the word, the static clock.
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        // StandBy renders this same activity, but across a whole propped-up
        // phone rather than in a banner. There is no environment value that
        // names StandBy, so the switch is on the width we are actually handed:
        // the lock-screen banner is the phone's width and change, StandBy is
        // the long edge. 480pt sits in the gap with room on both sides.
        GeometryReader { geo in
            if geo.size.width >= 480 {
                StandByCard(context: context, dimmed: dimmed)
            } else {
                banner
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        // The banner's own height, so the lock screen does not gain a
        // GeometryReader's greedy vertical appetite: the design's 15pt
        // insets around a 30pt clock under two lines of text.
        .frame(height: 108)
    }

    private var banner: some View {
        let palette = LaPalette.forScheme(scheme)
        let state = context.state
        return HStack(spacing: 13) {
            ZStack {
                Circle().fill(palette.well)
                StateCube(state: state, color: palette.ice)
                    .frame(width: 38, height: 38)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 0) {
                ModeLabel(frozen: state.frozen, mode: state.prismMode,
                          color: state.frozen || state.isDone ? palette.ice : palette.sub,
                          size: 13, glyphSize: 14, done: state.isDone)
                Text(FocusLiveActivity.title(context.attributes))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .padding(.top, 1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TimeReadout(state: state, size: 30,
                                ink: palette.ink, ice: palette.ice,
                                width: 90, tracking: -1)
                    Text(state.isDone ? "focused" : "left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.sub)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if #available(iOS 17.0, *) {
                // One press, no unlock. An interrupted student holds the
                // session without finding the app, and without it dying.
                // Done, there is nothing left to press; stale, nothing left to
                // hold.
                if !state.isDone && !context.sessionIsStale {
                    FreezeButton(frozen: state.frozen, fill: palette.button, ink: palette.buttonInk)
                }
            }
        }
        .padding(.leading, 15)
        .padding(.trailing, 14)
        .padding(.vertical, 15)
    }
}

/// Charging, landscape, propped beside you (la-standby, la-standby-frozen).
///
/// The same activity as the lock screen and deliberately not a second design —
/// but the banner's proportions are wrong across a whole phone, so the parts
/// are re-laid rather than re-invented: the cube large enough to read from
/// across a room, the clock as the loudest thing on the panel, the straight
/// rail, Freeze (Resume) and End. Always black. Laid out on the design's
/// 874 x 402 and scaled to whatever the system hands it.
@available(iOS 16.1, *)
struct StandByCard: View {
    let context: ActivityViewContext<FocusActivityAttributes>
    var dimmed: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width / 874, geo.size.height / 402, 1)
            let state = context.state
            HStack(spacing: 44 * s) {
                StateCube(state: state, color: AqColor.iceOnDark)
                    .frame(width: 200 * s, height: 200 * s)
                    .opacity(dimmed ? 0.55 : 1)

                VStack(alignment: .leading, spacing: 10 * s) {
                    ModeLabel(frozen: state.frozen, mode: state.prismMode,
                              color: AqColor.iceOnDark,
                              size: 17 * s, glyphSize: 18 * s, spacing: 6 * s,
                              done: state.isDone)
                    TimeReadout(state: state, size: 100 * s,
                                ink: .white, ice: AqColor.iceOnDark,
                                tracking: -3 * s)
                    Text(FocusLiveActivity.title(context.attributes))
                        .font(.system(size: 20 * s, weight: .bold))
                        .foregroundStyle(.white.opacity(dimmed ? 0.55 : 1))
                        .lineLimit(1)
                    if !state.isDone {
                        LaRail(spent: 1 - state.left, frozen: state.frozen,
                               ice: AqColor.iceOnDark, track: .white.opacity(0.14))
                            .padding(.top, 6 * s)
                            .opacity(dimmed ? 0.6 : 1)
                    }
                    if #available(iOS 17.0, *) {
                        // Propped on a desk is exactly when a student gets
                        // interrupted and cannot reach for the phone properly.
                        if !state.isDone {
                            SessionPills(frozen: state.frozen, scale: s,
                                         endOnly: context.sessionIsStale)
                                .frame(width: 300 * s)
                                .padding(.top, 10 * s)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 64 * s)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color.black)
        }
    }
}

/// What the cube loses, the rail gains — the straight form, for the surfaces
/// with room for it (the expanded Island, StandBy). Held, it dims to half.
@available(iOS 16.1, *)
struct LaRail: View {
    var spent: Double
    var frozen: Bool
    var ice: Color
    var track: Color

    var body: some View {
        GeometryReader { geo in
            let fraction = min(max(spent, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                if fraction > 0 {
                    Capsule()
                        .fill(ice)
                        .opacity(frozen ? 0.5 : 1)
                        .frame(width: max(6, geo.size.width * fraction))
                }
            }
        }
        .frame(height: 6)
    }
}

/// Freeze (Resume) and End: two equal pills, drawn here rather than left to
/// `.bordered`, whose capsule follows the control size rather than the 44pt
/// the design draws. The tap target is the whole pill.
@available(iOS 17.0, *)
struct SessionPills: View {
    var frozen: Bool
    var scale: CGFloat = 1
    /// A stale card: End alone, since a clock that has run out has nothing
    /// left to freeze.
    var endOnly: Bool = false

    var body: some View {
        HStack(spacing: 8 * scale) {
            // Two separate buttons rather than one with a chosen intent: the
            // intents are distinct types, so a ternary cannot produce them.
            if !endOnly {
                if frozen {
                    Button(intent: ResumeSessionIntent()) { pill(.play, "Resume") }
                } else {
                    Button(intent: FreezeSessionIntent()) { pill(.freeze, "Freeze") }
                }
            }
            Button(intent: EndSessionIntent()) { pill(.end, "End") }
        }
        .buttonStyle(.plain)
    }

    private func pill(_ glyph: AqGlyph, _ label: String) -> some View {
        HStack(spacing: 7 * scale) {
            AqGlyphView(glyph: glyph, color: AqColor.iceOnDark)
                .frame(width: 19 * scale, height: 19 * scale)
            Text(label)
                .font(.system(size: 15 * scale, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44 * scale)
        .background(Capsule().fill(Color.white.opacity(0.14)))
        .contentShape(Capsule())
    }
}

/// The lock screen's one press: Freeze, or Resume while held.
@available(iOS 17.0, *)
struct FreezeButton: View {
    var frozen: Bool
    var fill: Color
    var ink: Color
    var diameter: CGFloat = 50

    var body: some View {
        Group {
            if frozen {
                Button(intent: ResumeSessionIntent()) { disc(.play) }
            } else {
                Button(intent: FreezeSessionIntent()) { disc(.freeze) }
            }
        }
        .buttonStyle(.plain)
    }

    /// The circle is part of the button, not painted behind it.
    ///
    /// A plain-style button only hit-tests its label's drawn content, not the
    /// empty frame around it — so with the disc as a `.background` outside the
    /// label, the live target was the glyph in the middle, and a thumb landing
    /// anywhere else fell through to the activity, whose default action is to
    /// open the app. The press looked like it did nothing.
    private func disc(_ glyph: AqGlyph) -> some View {
        AqGlyphView(glyph: glyph, color: ink)
            .frame(width: diameter * 0.46, height: diameter * 0.46)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(fill))
            .contentShape(Circle())
    }
}

/// The lock-screen card's palette (the design's laT), light and dark.
@available(iOS 16.1, *)
struct LaPalette {
    let ink: Color
    let sub: Color
    let ice: Color
    let well: Color
    let button: Color
    let buttonInk: Color

    static func forScheme(_ scheme: ColorScheme) -> LaPalette {
        scheme == .dark ? dark : light
    }

    static let light = LaPalette(
        ink: Color(aqRGB: 0x111111),
        sub: Color(aqRGB: 0x5E5A6B),
        ice: AqColor.ice,
        well: Color(aqRGB: 0xECE9FB),
        button: Color(aqRGB: 0x111111),
        buttonInk: .white
    )

    static let dark = LaPalette(
        ink: .white,
        sub: .white.opacity(0.66),
        ice: AqColor.iceOnDark,
        well: .white.opacity(0.10),
        button: .white,
        buttonInk: Color(aqRGB: 0x111111)
    )
}

extension Color {
    /// The lock-screen card's platter: white at 82% by day, #1C1926 at 88% by
    /// night. A dynamic colour, because `activityBackgroundTint` is set where
    /// no environment can be read.
    static let laPlatform = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28 / 255, green: 25 / 255, blue: 38 / 255, alpha: 0.88)
            : UIColor(white: 1, alpha: 0.82)
    })

    /// Ink for the system's own controls on the platter.
    static let laPlatformInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(white: 17.0 / 255, alpha: 1)
    })
}
#endif
