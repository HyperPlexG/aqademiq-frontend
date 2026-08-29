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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    // The subject's own colour, so a glance says which class
                    // this is before the words are read.
                    Circle()
                        .fill(Color(hex: state.nextTaskTint) ?? AdaPalette.accent)
                        .frame(width: 5, height: 5)
                    Text([state.nextTaskTime, state.nextTaskSubject]
                        .compactMap { $0 }
                        .joined(separator: " · "))
                        .font(.system(size: 10.5).monospaced())
                        .foregroundStyle(Color.widgetMeta)
                        .lineLimit(1)
                }
            } else {
                // Nothing scheduled is not a failure, and never says so.
                Text("Nothing scheduled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.widgetMeta)
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
                    VStack(spacing: 6) {
                        ZStack {
                            if shown {
                                // A day you showed up wears Ada's face.
                                AdaView(stage: 0, showsFace: true)
                            } else {
                                // A day you did not is an empty outline, never a
                                // puddle: absence is not depletion.
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.20), lineWidth: 1.2)
                                    .padding(1)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(Self.letters[index])
                            .font(.system(size: 8.5,
                                          weight: index == todayIndex ? .bold : .medium)
                                .monospaced())
                            .foregroundStyle(index == todayIndex
                                             ? AdaPalette.accent : Color.widgetMeta)
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
                .frame(height: 52)
            Spacer(minLength: 0)
            if let session = state.session {
                // A session is already running: show it rather than offering to
                // start a second one.
                Text(session.frozen ? "Frozen" : "In session")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(session.frozen ? AdaPalette.frostLit : Color.widgetMeta)
                    .frame(maxWidth: .infinity)
            } else if #available(iOS 17.0, *) {
                Button(intent: StartFiveIntent()) {
                    Text("Start 5")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background(AdaPalette.accent, in: RoundedRectangle(cornerRadius: 11))
                .foregroundStyle(.white)
            } else {
                Text("Start 5")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AdaPalette.accent, in: RoundedRectangle(cornerRadius: 11))
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
            .font(.system(size: 8.5, weight: .bold).monospaced())
            .tracking(1.1)
            .foregroundStyle(Color.widgetLabel)
    }
}

extension Color {
    /// The design's widget surfaces. These are dark by intent, not by theme:
    /// every mock in the spec sits on near-black, because that is where a
    /// melting purple cube reads.
    static let widgetBG = Color(red: 0.086, green: 0.082, blue: 0.110)   // #16151c
    static let widgetLabel = Color(red: 0.435, green: 0.424, blue: 0.490) // #6f6c7d
    static let widgetMeta = Color(red: 0.545, green: 0.529, blue: 0.596)  // #8b8798

    /// Parse `#RRGGBB` as written by the app into the shared state.
    init?(hex: String?) {
        guard var raw = hex?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = Int(raw, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension View {
    /// iOS 17 requires widgets to declare their background explicitly; earlier
    /// versions draw it themselves and reject the modifier.
    @ViewBuilder
    func containerBackgroundIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.padding(14).containerBackground(for: .widget) { Color.widgetBG }
        } else {
            self.padding(14).background(Color.widgetBG)
        }
    }
}

// MARK: - Bundle

@main
struct AmbientWidgetsBundle: WidgetBundle {
    /// Everything declared flat and unconditionally.
    ///
    /// The extension's own deployment floor is 16.1, so the widgets and the
    /// Live Activity need no availability checks — and they must not have any.
    /// Wrapping an `ActivityConfiguration` in a `@WidgetBundleBuilder`
    /// conditional type-erases it: the bundle still compiles, the widgets still
    /// appear, and the Live Activity silently never registers, so the app can
    /// start an activity that nothing is ever able to draw.
    ///
    /// Only the Control Centre control is genuinely newer, and it is the one
    /// thing still behind a check.
    var body: some Widget {
        NextTaskWidget()
        WeekWidget()
        FocusWidget()
        FocusRingWidget()
        NextInlineWidget()
        FocusLiveActivity()
        controls
    }

    /// Control Centre and the Action Button, from iOS 18 — a real gate.
    @WidgetBundleBuilder
    var controls: some Widget {
        if #available(iOS 18.0, *) {
            StartFiveControl()
        }
    }
}
