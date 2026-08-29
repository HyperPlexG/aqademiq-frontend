import SwiftUI
import WidgetKit

/// One read of the shared container, shared by all three widgets.
///
/// The extension is never asked to think: it reads a flat object the app has
/// already derived and draws it. No network, no models, no work.
struct AmbientEntry: TimelineEntry {
    let date: Date
    let state: AmbientState
}

struct AmbientProvider: TimelineProvider {
    func placeholder(in context: Context) -> AmbientEntry {
        AmbientEntry(date: Date(), state: AmbientState())
    }

    func getSnapshot(in context: Context, completion: @escaping (AmbientEntry) -> Void) {
        completion(AmbientEntry(date: Date(), state: AmbientStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AmbientEntry>) -> Void) {
        // A single entry, refreshed when the app publishes. Widgets are glanced
        // at, not watched, and a timeline of speculative future entries would
        // spend the refresh budget guessing at data the app already knows.
        let entry = AmbientEntry(date: Date(), state: AmbientStore.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

// MARK: - Next

/// One task. Not three, not a list.
///
/// The single question a student glances at their phone to answer is *what am I
/// meant to be doing*, and a list makes them choose again — which is the
/// decision that stalled them in the first place.
struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqNext", provider: AmbientProvider()) { entry in
            NextTaskView(state: entry.state)
                .containerBackgroundIfAvailable()
        }
        .configurationDisplayName("Next")
        .description("The one thing you're meant to be doing.")
        .supportedFamilies([.systemSmall])
    }
}

struct NextTaskView: View {
    let state: AmbientState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label_("Next")
            Spacer(minLength: 0)
            if let title = state.nextTaskTitle {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Text([state.nextTaskTime, state.nextTaskSubject]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                // Nothing scheduled is not a failure, and never says so.
                Text("Nothing scheduled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "aqademiq://plan"))
    }
}

// MARK: - This week

/// Seven marks, and no judgement.
///
/// A day the student showed up wears Ada's face; a day they did not is an empty
/// outline — never a puddle, because absence is not depletion. No count, no
/// percentage, no red, and nothing that reads as a decaying streak: the widget
/// is the surface with the least consent, so it never guilts.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqWeek", provider: AmbientProvider()) { entry in
            WeekView(state: entry.state)
                .containerBackgroundIfAvailable()
        }
        .configurationDisplayName("This week")
        .description("The days you showed up. No streak, no scolding.")
        .supportedFamilies([.systemSmall])
    }
}

struct WeekView: View {
    let state: AmbientState

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    /// Monday-first index of today, matching `AppDate.mondayOf` in the app.
    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label_("This week")
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    let shown = index < state.weekDays.count && state.weekDays[index]
                    VStack(spacing: 5) {
                        ZStack {
                            if shown {
                                AdaView(stage: 0, showsFace: true)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.primary.opacity(0.22), lineWidth: 1)
                            }
                        }
                        .frame(height: 20)
                        Text(Self.letters[index])
                            .font(.system(size: 8, weight: index == todayIndex ? .bold : .regular))
                            .foregroundStyle(index == todayIndex ? Color.adaAccent_ : .secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "aqademiq://stats"))
    }
}

// MARK: - Start 5

/// The one operable thing on any widget.
///
/// Ticking tasks from the home screen sounds useful and produces mis-taps
/// against stale data — glance, then open. This button is the exception because
/// it does not act on data at all: it starts five minutes.
struct FocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqFocus", provider: AmbientProvider()) { entry in
            FocusWidgetView(state: entry.state)
                .containerBackgroundIfAvailable()
        }
        .configurationDisplayName("Focus")
        .description("Start five minutes without opening anything.")
        .supportedFamilies([.systemSmall])
    }
}

struct FocusWidgetView: View {
    let state: AmbientState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label_("Focus")
                Spacer()
            }
            Spacer(minLength: 0)
            AdaView(stage: state.session?.meltStage ?? 0,
                    frozen: state.session?.frozen ?? false)
                .frame(height: 46)
            Spacer(minLength: 0)
            if let session = state.session {
                // A session is already running: show it rather than offering to
                // start a second one.
                Text(session.frozen ? "Frozen" : "In session")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else if #available(iOS 17.0, *) {
                Button(intent: StartFiveIntent()) {
                    Text("Start 5")
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .background(Color.adaAccent_, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            } else {
                Text("Start 5")
                    .font(.system(size: 12.5, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.adaAccent_, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "aqademiq://focus/start5"))
    }
}

// MARK: - Shared bits

struct Label_: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold).monospaced())
            .tracking(1)
            .foregroundStyle(.secondary)
    }
}

extension Color {
    static let adaAccent_ = Color(red: 0.42, green: 0.36, blue: 0.94)
}

extension View {
    /// iOS 17 requires widgets to declare their background explicitly; earlier
    /// versions draw it themselves and reject the modifier.
    @ViewBuilder
    func containerBackgroundIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.padding(14).containerBackground(.fill.tertiary, for: .widget)
        } else {
            self.padding(14)
        }
    }
}

// MARK: - Bundle

@main
struct AmbientWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextTaskWidget()
        WeekWidget()
        FocusWidget()
        liveActivity
    }

    /// The Live Activity only exists from 16.1; the widgets reach further back.
    @WidgetBundleBuilder
    var liveActivity: some Widget {
        if #available(iOS 16.1, *) {
            FocusLiveActivity()
        }
    }
}
