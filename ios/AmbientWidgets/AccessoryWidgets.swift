import SwiftUI
import WidgetKit

#if canImport(AppIntents)
import AppIntents
#endif

/// The lock screen and Control Centre, from the same data as everything else.
///
/// Individually these are small. Together they are the difference between a
/// good implementation and one people write about — and none of them needed new
/// data, only a different shape for what the app already publishes.

// MARK: - Lock screen

/// Today's focus minutes as a ring, small enough to sit beside the clock
/// (la-lock's accessories: the ring, then the next block as a line).
@available(iOS 16.0, *)
struct FocusRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqFocusRing", provider: AmbientProvider()) { entry in
            FocusRingView(state: entry.state)
                .accessoryContainerIfAvailable()
        }
        .configurationDisplayName("Focus today")
        .description("Minutes focused today.")
        .supportedFamilies([.accessoryCircular])
    }
}

@available(iOS 16.0, *)
struct FocusRingView: View {
    let state: AmbientState

    /// An hour is a full ring. Not a target, and never drawn as a shortfall —
    /// this is a record of what happened, not a quota with a gap in it.
    private var fraction: Double {
        min(Double(state.focusMinToday) / 60, 1)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            // The design's 62pt ring in a 72pt chip: r 27, 4pt, on a faint
            // track of itself.
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.22)
                .padding(9)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(9)
            // Today's count only: the payload can be yesterday's until the
            // app next publishes.
            Text("\(state.focusMinToday)m")
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 12)
        }
        .widgetURL(URL(string: "aqademiq://stats"))
    }
}

/// The next task, on the lock screen, in one line.
@available(iOS 16.0, *)
struct NextInlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqNextInline", provider: AmbientProvider()) { entry in
            NextInlineView(state: entry.state)
                .accessoryContainerIfAvailable()
        }
        .configurationDisplayName("Next")
        .description("The one thing you're meant to be doing.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

@available(iOS 16.0, *)
struct NextInlineView: View {
    @Environment(\.widgetFamily) private var family
    let state: AmbientState

    var body: some View {
        if family == .accessoryInline {
            Text(inline)
        } else {
            // "Next · 2:00 PM" over the task, on the lock screen's chip.
            ZStack {
                AccessoryWidgetBackground()
                VStack(alignment: .leading, spacing: 1) {
                    Text(header)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(state.nextTaskTitle ?? "Nothing scheduled")
                        .font(.system(size: 15, weight: .heavy))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
            }
            .widgetURL(URL(string: "aqademiq://plan"))
        }
    }

    private var header: String {
        guard let time = state.nextTaskTime, state.nextTaskTitle != nil else { return "Next" }
        return "Next · \(time)"
    }

    private var inline: String {
        guard let title = state.nextTaskTitle else { return "Nothing scheduled" }
        guard let time = state.nextTaskTime else { return title }
        return "\(time) · \(title)"
    }
}

@available(iOS 16.0, *)
extension View {
    /// A lock-screen accessory draws its own chip (AccessoryWidgetBackground,
    /// inside the view), so the container is clear — but iOS 17 still requires
    /// one to be declared, and without it shows a placeholder instead.
    @ViewBuilder
    func accessoryContainerIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

// MARK: - Control Centre

#if canImport(AppIntents)
/// Swipe, press, working.
///
/// The same "start five minutes" intent as the widget button and the Action
/// Button, wearing different clothes — no app launch, no home-screen hunt.
@available(iOS 18.0, *)
struct StartFiveControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "AqademiqStartFive") {
            ControlWidgetButton(action: StartFiveIntent()) {
                Label("Start 5", systemImage: "timer")
            }
        }
        .displayName("Start 5")
        .description("Begin a five-minute focus session.")
    }
}
#endif
