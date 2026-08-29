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
                // Expanded — a long press. The task title is the point.
                DynamicIslandExpandedRegion(.leading) {
                    AdaView(stage: context.state.meltStage, frozen: context.state.frozen)
                        .frame(width: 42, height: 42)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeReadout(state: context.state, size: 25, weight: .bold)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.taskTitle)
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                        Text(subtitle(for: context))
                            .font(.system(size: 9.5, weight: .medium).monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        PuddleRail(spent: context.state.spent, frozen: context.state.frozen)
                        if #available(iOS 17.0, *) {
                            SessionControls(frozen: context.state.frozen)
                        }
                    }
                }
            } compactLeading: {
                // Ada leads, the clock trails. She is the only element that
                // ever changes here.
                AdaView(stage: context.state.meltStage,
                        frozen: context.state.frozen,
                        showsFace: false)
                    .frame(width: 22, height: 22)
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

    private func subtitle(for context: ActivityViewContext<FocusActivityAttributes>) -> String {
        [context.attributes.subjectLabel, context.state.prismMode]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
            .uppercased()
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

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.001, 1 - context.state.spent))
                    .stroke(
                        context.state.frozen ? Color.frostLit : Color.drip,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                AdaView(stage: context.state.meltStage, frozen: context.state.frozen)
                    .padding(9)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(header)
                    .font(.system(size: 9, weight: .semibold).monospaced())
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Text(context.attributes.taskTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                TimeReadout(state: context.state, size: 27, weight: .bold)
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
                    .frame(width: max(4, geo.size.width * min(max(spent, 0), 1)))
            }
        }
        .frame(height: 7)
    }
}

@available(iOS 17.0, *)
struct SessionControls: View {
    var frozen: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Two separate buttons rather than one with a chosen intent: the
            // intents are distinct types, so a ternary cannot produce them.
            if frozen {
                Button(intent: ResumeSessionIntent()) {
                    hold(label: "Resume", icon: "play.fill")
                }
                .tint(Color.frostLit.opacity(0.19))
            } else {
                Button(intent: FreezeSessionIntent()) {
                    hold(label: "Freeze", icon: "snowflake")
                }
                .tint(Color.frostLit.opacity(0.19))
            }

            Button(intent: EndSessionIntent()) {
                Text("End")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .tint(Color.white.opacity(0.07))
        }
        .buttonStyle(.bordered)
    }

    private func hold(label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity)
    }
}

@available(iOS 17.0, *)
struct FreezeButton: View {
    var frozen: Bool

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
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
    }
}

extension Color {
    static let adaAccent = Color(red: 0.42, green: 0.36, blue: 0.94)
    static let frostLit = Color(red: 0.62, green: 0.84, blue: 0.94)
    static let drip = Color(red: 0.75, green: 0.90, blue: 0.96)
}
#endif
