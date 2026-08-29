import Foundation

#if canImport(AppIntents)
import AppIntents

/// A press on a surface outside the app.
///
/// These run in the extension, not the app, and the app may not even be alive —
/// so the press is written into the shared container and the app reconciles
/// when it next attaches. That ordering is deliberate: the shared state is the
/// authority for what the surfaces show, so a Freeze taken on a dead process
/// still reads as frozen on the lock screen immediately, rather than waiting
/// for the app to wake up and agree.
@available(iOS 17.0, *)
enum SessionIntent {
    static var freeze: FreezeSessionIntent { FreezeSessionIntent() }
    static var resume: ResumeSessionIntent { ResumeSessionIntent() }
    static var end: EndSessionIntent { EndSessionIntent() }
}

/// Where a press waits for the app to pick it up.
@available(iOS 16.0, *)
enum PendingAction {
    static let key = "ambient_pending_action"

    static func park(_ action: String) {
        AmbientStore.defaults?.set(action, forKey: key)
    }

    /// Reflect the press in the shared state straight away, so the surfaces do
    /// not sit there looking unpressed until the app gets around to it.
    static func applyOptimistically(frozen: Bool) {
        guard
            let defaults = AmbientStore.defaults,
            let raw = defaults.string(forKey: AmbientStore.stateKey),
            let data = raw.data(using: .utf8),
            var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            var session = json["session"] as? [String: Any]
        else { return }

        session["frozen"] = frozen
        json["session"] = session
        if let encoded = try? JSONSerialization.data(withJSONObject: json),
           let string = String(data: encoded, encoding: .utf8) {
            defaults.set(string, forKey: AmbientStore.stateKey)
        }
    }
}

/// Hold the session. The tutorial teaches "freeze, don't quit"; this is that,
/// one press from anywhere, without unlocking and without the session dying.
@available(iOS 17.0, *)
struct FreezeSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Freeze session"
    static var description = IntentDescription("Hold your focus session without ending it.")

    func perform() async throws -> some IntentResult {
        PendingAction.park("freeze")
        PendingAction.applyOptimistically(frozen: true)
        return .result()
    }
}

@available(iOS 17.0, *)
struct ResumeSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume session"
    static var description = IntentDescription("Pick your focus session back up.")

    func perform() async throws -> some IntentResult {
        PendingAction.park("resume")
        PendingAction.applyOptimistically(frozen: false)
        return .result()
    }
}

@available(iOS 17.0, *)
struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End session"
    static var description = IntentDescription("Finish your focus session.")

    func perform() async throws -> some IntentResult {
        PendingAction.park("end")
        return .result()
    }
}

/// Start five minutes. Five, not twenty-five — the lowest possible barrier
/// between an idle thumb and a started session, and the same activation logic
/// the tutorial curriculum teaches.
///
/// The same intent wears four different clothes: the Focus widget's button, a
/// Control Centre control, the Action Button, and Siri.
@available(iOS 16.0, *)
struct StartFiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Start 5 minutes"
    static var description = IntentDescription("Begin a five-minute focus session.")

    /// Starting a session needs the app: the timer, Prism and the backend all
    /// live there, and none of that can be spun up from an extension.
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        PendingAction.park("startFive")
        return .result()
    }
}
#endif
