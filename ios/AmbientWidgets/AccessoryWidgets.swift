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

/// Today's focus minutes as a ring, small enough to sit beside the clock.
@available(iOS 16.0, *)
struct FocusRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqFocusRing", provider: AmbientProvider()) { entry in
            FocusRingView(state: entry.state)
                .containerBackgroundIfAvailable()
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
        min(Double(state.todayFocusMin) / 60, 1)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            Text("\(state.todayFocusMin)m")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .minimumScaleFactor(0.6)
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
                .containerBackgroundIfAvailable()
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
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT")
                    .font(.system(size: 9, weight: .semibold).monospaced())
                    .foregroundStyle(.secondary)
                Text(state.nextTaskTitle ?? "Nothing scheduled")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                if let time = state.nextTaskTime {
                    Text([time, state.nextTaskSubject].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(URL(string: "aqademiq://plan"))
        }
    }

    private var inline: String {
        guard let title = state.nextTaskTitle else { return "Nothing scheduled" }
        guard let time = state.nextTaskTime else { return title }
        return "\(time) · \(title)"
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
