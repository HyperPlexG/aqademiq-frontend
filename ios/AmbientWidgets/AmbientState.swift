import Foundation

/// The shared container both halves of the app read and write.
///
/// The app group is the only channel between the app and its extension: no
/// network, no database, no images. Everything here mirrors `AmbientState` in
/// `lib/services/ambient/ambient_state.dart` field for field, because a widget
/// that derives its own view of a session is a widget that will eventually
/// disagree with the app about what the session is.
enum AmbientStore {
    /// Must match the App Group on both the app and the extension.
    static let appGroup = "group.com.r13.aqademiq.shared"

    /// The glanceable payload, written by Dart on every publish.
    static let stateKey = "ambient_state"

    /// Rung inside the app's process when a press is parked.
    ///
    /// A LiveActivityIntent runs in the app's process, and during a focus
    /// session that process is alive — Prism holds an audio session — so the
    /// press can reach the running session immediately instead of waiting for
    /// the next foreground. Posted from the extension it reaches nobody, which
    /// is harmless: the parked press is still drained on foreground.
    static let pressParked = Notification.Name("com.r13.aqademiq.ambient.pressParked")

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func load() -> AmbientState {
        guard
            let raw = defaults?.string(forKey: stateKey),
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return AmbientState()
        }
        return AmbientState(json: json)
    }
}

/// A running session, as the surfaces outside the app see it.
struct AmbientSessionState {
    /// The instant the session is due to finish. Every countdown out here is
    /// rendered by the system from this, which is why nothing pushes the clock.
    let endsAt: Date

    /// Held, not stopped. A system countdown cannot be paused, so a frozen
    /// surface shows `remainingSec` as static text instead of a live timer.
    let frozen: Bool

    /// Ada's stage, `0..4`. The only thing the app ever pushes.
    let meltStage: Int

    let remainingSec: Int
    let durationSec: Int
    let taskTitle: String?
    let subjectLabel: String?
    let subjectTint: String?
    let prismMode: String?

    /// How much of the session has been spent, `0...1` — Ada's lost volume,
    /// which is exactly what the ring or the rail gains.
    var spent: Double {
        guard durationSec > 0 else { return 0 }
        let done = Double(durationSec - remainingSec)
        return min(max(done / Double(durationSec), 0), 1)
    }

    /// Time left, `0...1`: what the session cube is trimmed to. Read when the
    /// widget is drawn, so a running session measures from `endsAt`.
    var left: Double {
        guard durationSec > 0 else { return 1 }
        let seconds = frozen ? Double(remainingSec) : endsAt.timeIntervalSinceNow
        return min(max(seconds / Double(durationSec), 0), 1)
    }

    init?(json: [String: Any]) {
        guard
            let iso = json["endsAt"] as? String,
            let endsAt = Date.fromAmbientISO(iso)
        else { return nil }
        self.endsAt = endsAt
        self.frozen = json["frozen"] as? Bool ?? false
        self.meltStage = json["meltStage"] as? Int ?? 0
        self.remainingSec = json["remainingSec"] as? Int ?? 0
        self.durationSec = json["durationSec"] as? Int ?? 0
        self.taskTitle = json["taskTitle"] as? String
        self.subjectLabel = json["subjectLabel"] as? String
        self.subjectTint = json["subjectTint"] as? String
        self.prismMode = json["prismMode"] as? String
    }
}

/// The whole payload: the session, plus what the widgets show without one.
struct AmbientState {
    var session: AmbientSessionState?

    /// One task, never a list — a list makes a student choose again, and
    /// choosing again is the thing that stalls them.
    var nextTaskTitle: String?
    var nextTaskTime: String?
    var nextTaskSubject: String?
    var nextTaskTint: String?

    /// Seven flags, Monday first. A day the student showed up wears Ada's face;
    /// a day they did not is an empty outline, never a puddle — absence is not
    /// depletion.
    var weekDays: [Bool] = []

    /// The mood logged each day, `0` Rough … `4` Great, Monday first; nil for
    /// a day with no check-in. The This week row draws Ada at that mood.
    ///
    /// Written as `-1` for a day with no check-in, never null: the same payload
    /// goes to the watch as a property list, which has no null.
    var weekMoods: [Int?] = []

    /// The Monday the week row belongs to, `yyyy-MM-dd`, local. The payload is
    /// only rewritten when the app publishes, so after Monday's rollover it
    /// still holds last week's moods; another Monday than this one means
    /// every day is drawn as no check-in.
    var weekOf: String?

    var todayFocusMin: Int = 0

    /// The local day `todayFocusMin` counts, `yyyy-MM-dd`.
    var focusDay: String?

    init() {}

    /// Minutes focused today: the published count on the day it counts, and
    /// zero on any other — yesterday's total is not today's.
    var focusMinToday: Int {
        focusDay == AmbientDay.key(Date()) ? todayFocusMin : 0
    }

    /// The mood to draw for a day, or nil for an empty outline.
    ///
    /// A payload from before `weekMoods` existed still says which days were
    /// shown up for; those wear Ada at her best rather than going blank.
    /// Either way only if the payload is this week's.
    func mood(at index: Int) -> Int? {
        guard weekOf == AmbientDay.mondayKey(Date()) else { return nil }
        if !weekMoods.isEmpty {
            guard index < weekMoods.count, let mood = weekMoods[index] else { return nil }
            return min(max(mood, 0), 4)
        }
        return index < weekDays.count && weekDays[index] ? 4 : nil
    }

    /// What the widget gallery shows — the same task and week the v11 design
    /// draws (wg-home), so the three widgets are recognisable before they exist
    /// on anyone's home screen. Never written to the App Group; the gallery
    /// only.
    static var gallerySample: AmbientState {
        var state = AmbientState()
        state.nextTaskTitle = "Networks revision"
        state.nextTaskTime = "2:00 PM"
        state.nextTaskSubject = "CN 302"
        state.nextTaskTint = "#1F6FAE"
        state.weekDays = [true, true, false, false, false, false, false]
        state.weekMoods = [3, 2, nil, nil, nil, nil, nil]
        // Always this week: the sample is drawn, never read back.
        state.weekOf = AmbientDay.mondayKey(Date())
        return state
    }

    init(json: [String: Any]) {
        if let raw = json["session"] as? [String: Any] {
            session = AmbientSessionState(json: raw)
        }
        nextTaskTitle = json["nextTaskTitle"] as? String
        nextTaskTime = json["nextTaskTime"] as? String
        nextTaskSubject = json["nextTaskSubject"] as? String
        nextTaskTint = json["nextTaskTint"] as? String
        weekDays = (json["weekDays"] as? [Any])?.map { ($0 as? Bool) ?? false } ?? []
        // -1 (or anything else out of range) is a day with no check-in.
        weekMoods = (json["weekMoods"] as? [Any])?.map { raw -> Int? in
            guard let mood = raw as? Int, (0...4).contains(mood) else { return nil }
            return mood
        } ?? []
        weekOf = json["weekOf"] as? String
        todayFocusMin = json["todayFocusMin"] as? Int ?? 0
        focusDay = json["focusDay"] as? String
    }
}

/// Days as the app writes them (`ambientDay` in ambient_glance.dart): a local
/// calendar day as `yyyy-MM-dd`, the week starting on Monday.
///
/// Gregorian on purpose, in the device's own time zone: Dart's calendar is
/// Gregorian, and `Calendar.current` is not on a phone set to the Buddhist or
/// Japanese calendar, where the year alone would never match.
enum AmbientDay {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func key(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The Monday of the week `date` falls in — `AppDate.mondayOf` in the app.
    static func mondayKey(_ date: Date) -> String {
        let calendar = self.calendar
        let day = calendar.startOfDay(for: date)
        // Weekday is 1 for Sunday in the Gregorian calendar: Monday-first
        // index, as the week row's own `todayIndex` computes it.
        let sinceMonday = (calendar.component(.weekday, from: day) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: day) ?? day
        return key(monday)
    }
}

extension Date {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    /// Parse the instant Dart wrote, whatever precision it happened to use.
    ///
    /// `DateTime.toIso8601String()` emits milliseconds normally but *micro*
    /// seconds when they are non-zero, and `withFractionalSeconds` accepts only
    /// three digits — so a session started on an unlucky microsecond would fail
    /// to parse and the surface would silently show nothing. Truncating to
    /// milliseconds costs nothing here: the countdown is drawn to the second.
    static func fromAmbientISO(_ raw: String) -> Date? {
        if let date = fractional.date(from: raw) { return date }
        if let date = plain.date(from: raw) { return date }

        // Trim an over-long fraction down to three digits and retry.
        if let dot = raw.firstIndex(of: "."),
           let zone = raw.rangeOfCharacter(from: CharacterSet(charactersIn: "Z+-"),
                                           options: [],
                                           range: raw.index(after: dot)..<raw.endIndex) {
            let fraction = raw[raw.index(after: dot)..<zone.lowerBound]
            if fraction.count > 3 {
                let trimmed = raw[raw.startIndex...dot]
                    + fraction.prefix(3)
                    + raw[zone.lowerBound...]
                return fractional.date(from: String(trimmed))
            }
        }
        return nil
    }
}
