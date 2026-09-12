import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

/// The session, everywhere iOS will draw it.
///
/// One activity, four presentations: the lock-screen card, and the Island's
/// compact, minimal and expanded forms. All of them read the same state, and
/// none of them is ever told the time — `Text(timerInterval:)` counts down from
/// `endsAt` on its own, which is what makes a whole session cost five updates.
@available(iOS 16.1, *)
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — a long press. The task title is the point: a
                // student who long-presses at minute forty has usually
                // forgotten what they sat down to do.
                //
                // Everything lives in .bottom as one composed card rather than
                // spread across leading/trailing, because those regions are
                // narrow and wrap the title long before the space runs out.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // She sits in a disc, as the spec draws her. The
                            // disc is not decoration: the expanded Island is a
                            // wide dark field, and an unbacked silhouette at
                            // 46pt reads as a smudge floating in it.
                            ZStack {
                                Circle().fill(tint(for: context).opacity(0.20))
                                AdaView(stage: context.state.meltStage,
                                        frozen: context.state.frozen)
                                    .padding(6)
                            }
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(for: context))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                // Only when there is something to say. An
                                // empty caption still claims a line, and the
                                // title then sits high against the disc rather
                                // than centred on it.
                                if let subtitle = subtitle(for: context) {
                                    Text(subtitle)
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(0.9)
                                        .foregroundStyle(.white.opacity(0.45))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            // Fixed width, right-aligned, and both are needed.
                            //
                            // Text(timerInterval:) reserves room for the widest
                            // time it might ever show and centres inside it, so
                            // left to itself the clock floats in the middle of
                            // a wide blank column instead of sitting at the
                            // trailing edge the spec puts it at. Pinning the
                            // width also stops the title reflowing every time a
                            // digit changes shape.
                            TimeReadout(state: context.state, size: 34, weight: .bold)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 104, alignment: .trailing)
                                .layoutPriority(1)
                        }

                        PuddleRail(spent: context.state.spent,
                                   frozen: context.state.frozen)

                        if #available(iOS 17.0, *) {
                            SessionControls(frozen: context.state.frozen)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Ada leads, the clock trails. She is the only element that
                // ever changes here.
                //
                // She keeps her face. §4's "at 22pt the face is gone" is
                // labelled MINIMAL ISLAND and applies to that presentation
                // only — §2 draws the compact one with her eyes and smile, and
                // without them a stage-0 cube is a bare rounded rectangle
                // (tL 11, tR 49, r 9), which is what shipped and what read as
                // a purple square rather than as Ada.
                AdaView(stage: context.state.meltStage,
                        frozen: context.state.frozen)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                TimeReadout(state: context.state, size: 15, weight: .semibold)
                    .frame(maxWidth: 54)
            } minimal: {
                // Sharing the Island with another activity: a circle is all we
                // get. A cube silhouette is legible at 22pt where a generic
                // glyph is not — this is where the mascot pays for itself.
                AdaView(stage: context.state.meltStage,
                        frozen: context.state.frozen,
                        showsFace: false)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(context.state.frozen ? .frostLit : .adaAccent)
        }
    }

    /// The subject's own colour, falling back to the accent.
    private func tint(for context: ActivityViewContext<FocusActivityAttributes>) -> Color {
        Color(hex: context.attributes.subjectTint) ?? .adaAccent
    }

    /// What the student sat down to do — or, when they started five minutes
    /// from a widget and there is no task at all, something true rather than an
    /// empty string. A blank title collapsed the middle column entirely and
    /// left the Island looking like a bug.
    private func title(for context: ActivityViewContext<FocusActivityAttributes>) -> String {
        let given = context.attributes.taskTitle.trimmingCharacters(in: .whitespaces)
        return given.isEmpty ? "Focus session" : given
    }

    /// Nil rather than "" when there is nothing to show, so the caller can drop
    /// the line instead of laying out an empty one.
    private func subtitle(for context: ActivityViewContext<FocusActivityAttributes>) -> String? {
        let parts = [context.attributes.subjectLabel, context.state.prismMode]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ").uppercased()
    }
}

/// The countdown, or the held time.
///
/// The whole design rests on this one distinction: while running, the system
/// ticks `Text(timerInterval:)` for free and the app never wakes; while frozen,
/// a live timer would keep counting down a session that is not running, so it
/// is replaced by static text. Unhandled, that single detail makes the feature
/// worse than not shipping it.
@available(iOS 16.1, *)
struct TimeReadout: View {
    let state: FocusActivityAttributes.ContentState
    var size: CGFloat
    var weight: Font.Weight

    var body: some View {
        Group {
            if state.frozen {
                Text(staticRemaining)
                    .foregroundStyle(Color.frostLit)
            } else {
                Text(timerInterval: Date.now...state.endsAt,
                     pauseTime: nil,
                     countsDown: true)
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: size, weight: weight).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var staticRemaining: String {
        let safe = max(0, state.remainingSec)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }
}

/// The lock-screen card.
///
/// The ring is the rail, curled up: one number, read twice — Ada's volume and
/// the ring closing around her. No second progress bar, no percentage caption.
@available(iOS 16.1, *)
struct LockScreenCard: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    /// Always-On and StandBy's night mode both dim the panel. Colour is the
    /// first thing they take, which is why frozen has to stay distinguishable
    /// by silhouette — §4's "never by hue alone".
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
            }
        }
        // The banner's own height, so the lock screen does not gain a
        // GeometryReader's greedy vertical appetite.
        .frame(height: 88)
    }

    private var banner: some View {
        HStack(spacing: 13) {
            // The ring is the rail, curled up: one number read twice — Ada's
            // volume, and the ring closing around her. No second bar anywhere
            // on this card, and no percentage caption.
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 4.5)
                Circle()
                    .trim(from: 0, to: max(0.004, 1 - context.state.spent))
                    .stroke(
                        context.state.frozen
                            ? AnyShapeStyle(Color.frostLit.opacity(0.75))
                            : AnyShapeStyle(AngularGradient(
                                colors: [.drip, tint, .drip],
                                center: .center)),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                AdaView(stage: context.state.meltStage, frozen: context.state.frozen)
                    .padding(8)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(header)
                    .font(.system(size: 9, weight: .bold).monospaced())
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                Text(context.attributes.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                     ? "Focus session" : context.attributes.taskTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                TimeReadout(state: context.state, size: 30, weight: .bold)
            }

            Spacer(minLength: 0)

            if #available(iOS 17.0, *) {
                // One press, no unlock. An interrupted student holds the
                // session without finding the app, and without it dying.
                FreezeButton(frozen: context.state.frozen)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var header: String {
        let state = context.state.frozen ? "Frozen" : (context.state.prismMode ?? "Focus")
        return "AQADEMIQ · \(state.uppercased())"
    }

    /// The subject's own colour, falling back to the accent.
    private var tint: Color {
        Color(hex: context.attributes.subjectTint) ?? .adaAccent
    }
}

/// Charging, landscape, propped beside you.
///
/// The same activity as the lock screen and deliberately not a second design —
/// but the banner's proportions are wrong across a whole phone, so the parts
/// are re-laid rather than re-invented: Ada large enough to read from across a
/// room, the clock as the loudest thing on the panel, and the straight rail
/// instead of the ring, because there is room for it here.
@available(iOS 16.1, *)
struct StandByCard: View {
    let context: ActivityViewContext<FocusActivityAttributes>
    var dimmed: Bool

    var body: some View {
        HStack(spacing: 26) {
            AdaView(stage: context.state.meltStage, frozen: context.state.frozen)
                .frame(width: 116, height: 116)
                .opacity(dimmed ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 6) {
                TimeReadout(state: context.state, size: 68, weight: .bold)
                    .minimumScaleFactor(0.5)

                Text(context.attributes.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                     ? "Focus session" : context.attributes.taskTitle)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white.opacity(dimmed ? 0.55 : 0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                PuddleRail(spent: context.state.spent, frozen: context.state.frozen)
                    .padding(.top, 4)
                    .opacity(dimmed ? 0.6 : 1)

                Text(label)
                    .font(.system(size: 11, weight: .bold).monospaced())
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(dimmed ? 0.32 : 0.45))
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)

            if #available(iOS 17.0, *) {
                // Propped on a desk is exactly when a student gets interrupted
                // and cannot reach for the phone properly. One press, no unlock
                // — the same control as the lock screen, at the size the
                // distance calls for.
                FreezeButton(frozen: context.state.frozen, diameter: 64)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var label: String {
        let mode = context.state.frozen ? "Frozen" : (context.state.prismMode ?? "Focus")
        return mode.uppercased()
    }
}

/// What Ada loses, the rail gains — the straight form, for the surfaces with
/// room for it (the expanded Island, StandBy, the Android card).
@available(iOS 16.1, *)
struct PuddleRail: View {
    var spent: Double
    var frozen: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10))
                Capsule()
                    .fill(
                        frozen
                            ? AnyShapeStyle(Color.frostLit.opacity(0.55))
                            : AnyShapeStyle(LinearGradient(
                                colors: [.drip, .frostLit],
                                startPoint: .leading,
                                endPoint: .trailing))
                    )
                    .frame(width: max(8, geo.size.width * min(max(spent, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

@available(iOS 17.0, *)
struct SessionControls: View {
    var frozen: Bool

    /// Two equal slabs, drawn here rather than left to `.bordered`.
    ///
    /// The bordered style with a tint renders a capsule whose height follows
    /// the control size, and the spec draws a 44pt rounded rectangle at radius
    /// 12 with a flat fill. Styling around the system button meant fighting it
    /// on both counts, so the shape is explicit and the button carries no style
    /// of its own. The tap target is the whole slab either way.
    var body: some View {
        HStack(spacing: 9) {
            // Two separate buttons rather than one with a chosen intent: the
            // intents are distinct types, so a ternary cannot produce them.
            if frozen {
                Button(intent: ResumeSessionIntent()) {
                    slab(label: "Resume", icon: "play.fill",
                         ink: .frostLit, fill: Color.frostLit.opacity(0.16))
                }
            } else {
                Button(intent: FreezeSessionIntent()) {
                    slab(label: "Freeze", icon: "snowflake",
                         ink: .frostLit, fill: Color.frostLit.opacity(0.16))
                }
            }

            Button(intent: EndSessionIntent()) {
                slab(label: "End", icon: nil,
                     ink: .white.opacity(0.72), fill: Color.white.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
    }

    private func slab(label: String, icon: String?, ink: Color, fill: Color) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            }
            Text(label).font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
    }
}

@available(iOS 17.0, *)
struct FreezeButton: View {
    var frozen: Bool
    /// 44 on the lock screen; StandBy is read from across a room.
    var diameter: CGFloat = 44

    var body: some View {
        Group {
            if frozen {
                Button(intent: ResumeSessionIntent()) { glyph("play.fill") }
            } else {
                Button(intent: FreezeSessionIntent()) { glyph("snowflake") }
            }
        }
        .buttonStyle(.plain)
        .background(Circle().fill(.white))
        .foregroundStyle(.black)
    }

    private func glyph(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: diameter * 0.39, weight: .semibold))
            .frame(width: diameter, height: diameter)
    }
}

extension Color {
    static let adaAccent = AdaPalette.accent
    static let frostLit = AdaPalette.frostLit
    static let drip = AdaPalette.drip
}
#endif
