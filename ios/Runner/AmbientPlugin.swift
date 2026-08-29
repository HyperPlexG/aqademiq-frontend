import Flutter
import Foundation
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit
#endif

/// The iOS half of `aqademiq/ambient`.
///
/// Three jobs, and the order between them matters:
///
///  * write the flat state into the App Group, which is the only thing the
///    widgets can read when the app is not running;
///  * keep the Live Activity in step with the session — started when one
///    begins, ended the moment it stops, because the Island is taken for a
///    running session and nothing else;
///  * carry presses back. A Freeze from the lock screen runs in the extension
///    and parks itself in the shared container, so the app drains that on every
///    foreground and reconciles.
final class AmbientPlugin: NSObject {
    static let channelName = "aqademiq/ambient"

    private let channel: FlutterMethodChannel
    private var currentActivityID: String?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    // MARK: - Channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startSession":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "session payload missing", details: nil))
                return
            }
            store(session: args)
            startActivity(args)
            reloadWidgets()
            result(nil)

        case "updateSession":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "session payload missing", details: nil))
                return
            }
            store(session: args)
            updateActivity(args)
            reloadWidgets()
            result(nil)

        case "endSession":
            store(session: nil)
            endActivity()
            reloadWidgets()
            result(nil)

        case "publish":
            if let args = call.arguments as? [String: Any] { publish(args) }
            reloadWidgets()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// A tapped widget, handed to Dart as intent rather than as a route.
    ///
    /// Returns false for anything that is not ours, so the Google Sign-In
    /// scheme sharing this callback still reaches its own handler.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "aqademiq" else { return false }
        // aqademiq://focus/start5 → "focus/start5"
        let route = ((url.host ?? "") + url.path).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !route.isEmpty else { return false }
        channel.invokeMethod("route", arguments: route)
        return true
    }

    /// Replay a press taken on a surface while the app was not listening.
    ///
    /// Called on every foreground: the intents behind Freeze and Start 5 run in
    /// the extension and cannot reach into the session themselves, so they leave
    /// the press here for the app to find.
    func drainPendingAction() {
        guard
            let defaults = UserDefaults(suiteName: Self.appGroup),
            let action = defaults.string(forKey: "ambient_pending_action")
        else { return }
        defaults.removeObject(forKey: "ambient_pending_action")
        channel.invokeMethod("action", arguments: action)
    }

    // MARK: - Shared container

    private static let appGroup = "group.com.r13.aqademiq.ambient"
    private static let stateKey = "ambient_state"

    private var defaults: UserDefaults? { UserDefaults(suiteName: Self.appGroup) }

    /// Merge the session into the stored payload without disturbing the
    /// glanceable half, so a session starting does not blank the widgets.
    private func store(session: [String: Any]?) {
        var json = loadState()
        if let session { json["session"] = session } else { json.removeValue(forKey: "session") }
        write(json)
    }

    private func publish(_ state: [String: Any]) {
        var json = state
        // A publish carries the glanceable data; the live session is owned by
        // start/update/end and must survive it.
        if json["session"] == nil, let existing = loadState()["session"] {
            json["session"] = existing
        }
        write(json)
    }

    private func loadState() -> [String: Any] {
        guard
            let raw = defaults?.string(forKey: Self.stateKey),
            let data = raw.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }

    private func write(_ json: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: json),
            let string = String(data: data, encoding: .utf8)
        else { return }
        defaults?.set(string, forKey: Self.stateKey)
    }

    private func reloadWidgets() {
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Live Activity

    private func startActivity(_ args: [String: Any]) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        // Never two. A session that restarts replaces the activity rather than
        // stacking a second one in the Island.
        endActivity()
        guard
            ActivityAuthorizationInfo().areActivitiesEnabled,
            let state = contentState(args)
        else { return }

        let attributes = FocusActivityAttributes(
            taskTitle: args["taskTitle"] as? String ?? "Focus session",
            subjectLabel: args["subjectLabel"] as? String,
            subjectTint: args["subjectTint"] as? String
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            currentActivityID = activity.id
        } catch {
            // A device that will not host an activity is not a session that has
            // gone wrong; the app carries on and the widgets still update.
            NSLog("Ambient: could not start Live Activity — \(error.localizedDescription)")
        }
        #endif
    }

    private func updateActivity(_ args: [String: Any]) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let state = contentState(args) else { return }
        guard let activity = Activity<FocusActivityAttributes>.activities
            .first(where: { $0.id == currentActivityID }) ?? Activity<FocusActivityAttributes>.activities.first
        else {
            // Nothing on screen to update — the session outlived its activity
            // (an app restart, usually), so put one back.
            startActivity(args)
            return
        }
        Task { await activity.update(using: state) }
        #endif
    }

    private func endActivity() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        currentActivityID = nil
        for activity in Activity<FocusActivityAttributes>.activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
        }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private func contentState(_ args: [String: Any]) -> FocusActivityAttributes.ContentState? {
        guard
            let iso = args["endsAt"] as? String,
            let endsAt = Date.fromAmbientISO(iso)
        else { return nil }
        return FocusActivityAttributes.ContentState(
            endsAt: endsAt,
            frozen: args["frozen"] as? Bool ?? false,
            meltStage: args["meltStage"] as? Int ?? 0,
            remainingSec: args["remainingSec"] as? Int ?? 0,
            durationSec: args["durationSec"] as? Int ?? 0,
            prismMode: args["prismMode"] as? String
        )
    }
    #endif
}
