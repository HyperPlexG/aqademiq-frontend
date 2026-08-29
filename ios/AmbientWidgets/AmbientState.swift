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
    static let appGroup = "group.com.r13.aqademiq.ambient"

    /// The glanceable payload, written by Dart on every publish.
    static let stateKey = "ambient_state"

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

    var todayFocusMin: Int = 0

    init() {}

    init(json: [String: Any]) {
        if let raw = json["session"] as? [String: Any] {
            session = AmbientSessionState(json: raw)
        }
        nextTaskTitle = json["nextTaskTitle"] as? String
        nextTaskTime = json["nextTaskTime"] as? String
        nextTaskSubject = json["nextTaskSubject"] as? String
        nextTaskTint = json["nextTaskTint"] as? String
        weekDays = (json["weekDays"] as? [Any])?.map { ($0 as? Bool) ?? false } ?? []
        todayFocusMin = json["todayFocusMin"] as? Int ?? 0
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
