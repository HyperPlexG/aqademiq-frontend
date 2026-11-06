import SwiftUI
import WidgetKit
#if canImport(UIKit)
import UIKit
#endif

/// One read of the shared container, shared by all three widgets.
///
/// The extension is never asked to think: it reads a flat object the app has
/// already derived and draws it. No network, no models, no work.
struct AmbientEntry: TimelineEntry {
    let date: Date
    let state: AmbientState
}

struct AmbientProvider: TimelineProvider {
    /// The design's own sample, drawn rather than redacted.
    ///
    /// An empty state here is what the system turns into grey bars, and the
    /// gallery is a first impression: most apps let the OS show a grey
    /// placeholder there, and the pick should be obvious before anything is
    /// installed.
    func placeholder(in context: Context) -> AmbientEntry {
        AmbientEntry(date: Date(), state: .gallerySample)
    }

    /// The gallery gets the sample; the home screen gets the truth.
    ///
    /// Showing the real state in the gallery sounds more honest and is worse:
    /// the student browsing it is overwhelmingly a new one, so the real state
    /// is "Nothing scheduled" over an empty week — the least persuasive picture
    /// of each widget, at the one moment it is being chosen.
    func getSnapshot(in context: Context, completion: @escaping (AmbientEntry) -> Void) {
        let state = context.isPreview ? AmbientState.gallerySample : AmbientStore.load()
        completion(AmbientEntry(date: Date(), state: state))
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

/// wg-home's Next: the label, the task large, and the time and class under a
/// dot in the class's own colour.
struct NextTaskView: View {
    let state: AmbientState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetLabel("Next")
            if let title = state.nextTaskTitle {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.widgetInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                Spacer(minLength: 4)
                if let meta = meta {
                    HStack(spacing: 6) {
                        // The subject's own colour, so a glance says which
                        // class this is before the words are read.
                        Circle()
                            .fill(Color(hex: state.nextTaskTint) ?? AqColor.ice)
                            .frame(width: 8, height: 8)
                        Text(meta)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.widgetSub)
                            .lineLimit(1)
                    }
                }
            } else {
                // Nothing scheduled is not a failure, and never says so.
                Text("Nothing scheduled")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Color.widgetSub)
                    .padding(.top, 6)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "aqademiq://plan"))
    }

    /// "2:00 PM · CN 302".
    private var meta: String? {
        let parts = [state.nextTaskTime, state.nextTaskSubject]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - This week

/// Seven marks, and no judgement.
///
/// A day the student checked in wears Ada at the mood they logged, as the
/// app's own week row draws her; a day they did not is an empty dashed outline
/// — never a puddle, because absence is not depletion. Today, still open, is
/// the outline in the accent with a "+". No count, no percentage, no red, and
/// nothing that reads as a decaying streak: the widget is the surface with the
/// least consent, so it never guilts.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqademiqWeek", provider: AmbientProvider()) { entry in
            WeekView(state: entry.state)
                .containerBackgroundIfAvailable()
        }
        .configurationDisplayName("This week")
        .description("The days you showed up. No streak, no scolding.")
        // Medium, because seven cells cannot fit a small widget; the design
        // draws this one wide for exactly that reason.
        .supportedFamilies([.systemMedium])
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
        VStack(alignment: .leading, spacing: 0) {
            WidgetLabel("This week")
            Spacer(minLength: 0)
            // Spread edge to edge (space-between), as the row is in the app.
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 3) {
                        day(index)
                            .frame(width: 34, height: 34)
                        Text(Self.letters[index])
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(index == todayIndex ? AqColor.ice : Color.widgetDim)
                    }
                    if index < 6 {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "aqademiq://stats"))
    }

    @ViewBuilder
    private func day(_ index: Int) -> some View {
        if let mood = state.mood(at: index) {
            AqArtView(art: AqArt.moods[mood])
                .frame(width: 30, height: 30)
        } else {
            let today = index == todayIndex
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(today ? AqColor.ice : Color.widgetDayEmpty,
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                if today {
                    Text("+")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AqColor.ice)
                }
            }
            .frame(width: 27, height: 27)
        }
    }
}

// MARK: - Focus

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

/// wg-home's Focus: Ada, and "Start 5 min". While a session runs it shows the
/// session's cube and says so, rather than offering to start a second one.
struct FocusWidgetView: View {
    let state: AmbientState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                WidgetLabel("Focus")
                    .padding(.leading, 2)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Group {
                if let session = state.session {
                    SessionCube(left: session.left, color: Color.widgetIce)
                } else {
                    AqArtView(art: .brandAda)
                }
            }
            .frame(width: 54, height: 54)
            Spacer(minLength: 0)
            if let session = state.session {
                pill(session.frozen ? "Frozen" : "In session",
                     ink: session.frozen ? Color.widgetIce : Color.widgetSub,
                     fill: Color.widgetWell)
            } else if #available(iOS 17.0, *) {
                Button(intent: StartFiveIntent()) { startPill }
                    .buttonStyle(.plain)
            } else {
                startPill
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "aqademiq://focus/start5"))
    }

    private var startPill: some View {
        pill("Start 5 min", ink: .white, fill: AqColor.ice)
    }

    private func pill(_ text: String, ink: Color, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
    }
}

// MARK: - Shared bits

/// The label every widget opens with: "Next", "This week", "Focus".
struct WidgetLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.widgetSub)
            .lineLimit(1)
    }
}

extension Color {
    /// The widget card follows the theme in v11 (wg-home): white by day,
    /// #1C1C1E by night.
    static let widgetCard = Color.aqDynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let widgetInk = Color.aqDynamic(light: 0x111111, dark: 0xFFFFFF)
    static let widgetSub = Color.aqDynamic(light: 0x6E6E73, dark: 0xA1A1A8)
    /// The week's letters (DIM).
    static let widgetDim = Color.aqDynamic(light: 0xA7A7A7, dark: 0x505050)
    /// Ice on the card: --aq-ice by day, --aq-ice-on-dark by night.
    static let widgetIce = Color.aqDynamic(light: 0x6B5CF0, dark: 0xCBBCFD)
    /// The well a status sits in.
    static let widgetWell = Color.aqDynamic(light: 0xECE9FB, dark: 0xFFFFFF, darkAlpha: 0.10)
    /// A day with no check-in: the dashed outline, the same in both themes.
    static let widgetDayEmpty = Color(aqRGB: 0xD8D4CC)

    /// A light / dark pair, resolved by the system as the widget is drawn.
    static func aqDynamic(light: UInt32, dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
        func ui(_ rgb: UInt32, _ alpha: CGFloat) -> UIColor {
            UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: alpha
            )
        }
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? ui(dark, darkAlpha) : ui(light, 1)
        })
    }

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
    /// The home-screen card. iOS 17 requires widgets to declare their
    /// background explicitly, and applies the system's content margins itself
    /// — padding added on top of those doubled the inset and left the v11
    /// content no room. Earlier versions draw the background themselves and
    /// reject the modifier, so they get the design's 16 by hand.
    @ViewBuilder
    func containerBackgroundIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { Color.widgetCard }
        } else {
            self.padding(16).background(Color.widgetCard)
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
