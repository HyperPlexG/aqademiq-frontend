import Foundation

#if canImport(AppIntents)
import AppIntents
#if canImport(ActivityKit)
import ActivityKit
#endif

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
    ///
    /// This is the *widgets'* copy of the truth. It is not what the Live
    /// Activity renders from — see `restate` below, which was the missing half:
    /// a press updated the container, the container drives the home screen, and
    /// the Island went on showing exactly what it showed before. From the
    /// student's side the button did nothing.
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

#if canImport(ActivityKit)
/// Redraw the Live Activity from the press, immediately.
///
/// The activity renders from ActivityKit's own ContentState, which nothing in
/// the shared container touches. Parking the press and waiting for the app to
/// reconcile leaves the Island and the lock screen showing the old state for as
/// long as it takes the student to open the app — which, for a control whose
/// entire promise is "one press, no unlock", is indistinguishable from a dead
/// button.
///
/// Updating from the intent is the documented shape for an interactive Live
/// Activity, and the app still reconciles afterwards: this moves the pixels,
/// the app moves the session.
@available(iOS 17.0, *)
enum ActivityEcho {
    static func freeze(_ frozen: Bool) async {
        for activity in Activity<FocusActivityAttributes>.activities {
            var state = activity.content.state
            guard state.frozen != frozen else { continue }
            state.frozen = frozen
            if frozen {
                // A system countdown cannot be paused, so pin what is left at
                // the moment of the press — that number is what the frozen
                // surfaces draw instead of a ticking clock.
                state.remainingSec = max(0, Int(state.endsAt.timeIntervalSinceNow.rounded()))
            } else {
                // Held time is not spent time: the end moves out by however
                // long the hold lasted, which is exactly the remaining time we
                // pinned when it started.
                state.endsAt = Date().addingTimeInterval(TimeInterval(state.remainingSec))
            }
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    static func end() async {
        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif

/// Hold the session. The tutorial teaches "freeze, don't quit"; this is that,
/// one press from anywhere, without unlocking and without the session dying.
@available(iOS 17.0, *)
struct FreezeSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Freeze session"
    static var description = IntentDescription("Hold your focus session without ending it.")

    func perform() async throws -> some IntentResult {
        PendingAction.park("freeze")
        PendingAction.applyOptimistically(frozen: true)
        #if canImport(ActivityKit)
        await ActivityEcho.freeze(true)
        #endif
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
        #if canImport(ActivityKit)
        await ActivityEcho.freeze(false)
        #endif
        return .result()
    }
}

@available(iOS 17.0, *)
struct EndSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End session"
    static var description = IntentDescription("Finish your focus session.")

    func perform() async throws -> some IntentResult {
        PendingAction.park("end")
        #if canImport(ActivityKit)
        await ActivityEcho.end()
        #endif
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
