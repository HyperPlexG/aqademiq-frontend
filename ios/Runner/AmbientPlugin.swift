import Flutter
import Foundation
import UIKit
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
///    running session and nothing else. A session that ran to its end is
///    ended with a final "Session done" content (la-lock-done) that the lock
///    screen keeps for a few minutes; an ended activity is never drawn in the
///    Island, so that rule still holds;
///  * carry presses back. A Freeze from the lock screen runs in the extension
///    and parks itself in the shared container, so the app drains that on every
///    foreground and reconciles.
final class AmbientPlugin: NSObject {
    static let channelName = "aqademiq/ambient"

    private let channel: FlutterMethodChannel
    private var currentActivityID: String?

    /// Set by Dart's `ready` call, once its method-call handler is installed.
    private var dartIsListening = false

    /// The wrist. Every other surface reads the App Group; the watch is a
    /// separate device and needs a transport, so it is the one place this
    /// plugin pushes rather than publishes.
    private let watch = WatchBridge()

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        // A press on the watch goes through the same door as a press on a
        // widget: park it in the shared container, then drain it. Reusing that
        // path rather than invoking the channel directly means one reconcile
        // to reason about, and it already handles the case where the app was
        // not running when the press happened.
        watch.onCommand = { [weak self] action in
            guard let self else { return }
            self.defaults?.set(action, forKey: "ambient_pending_action")
            self.drainPendingAction()
        }
        watch.activate()
        // A press taken on the lock screen or the Island while the app is
        // alive in the background: drain it now rather than on the next
        // foreground. Main queue, because the other end is a Flutter channel.
        NotificationCenter.default.addObserver(
            forName: AmbientStore.pressParked, object: nil, queue: .main
        ) { [weak self] _ in
            self?.drainPendingAction()
        }
        // Every foreground, under the scene lifecycle too. With a scene
        // manifest UIKit tells the scene, not the app delegate, so
        // `applicationDidBecomeActive` is not a call to rely on; draining on
        // both is harmless, since a drain consumes what it delivers.
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.drainPendingAction()
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
            // Present only when the session ran to its end: the seconds spent,
            // for the done card. Ended early, or anything else, ends at once.
            let focusedSec = (call.arguments as? [String: Any])?["focusedSec"] as? Int
            endActivity(focusedSec: focusedSec)
            reloadWidgets()
            result(nil)

        case "publish":
            if let args = call.arguments as? [String: Any] { publish(args) }
            reloadWidgets()
            result(nil)

        case "ready":
            // Dart has a handler now. Anything parked before this point was
            // being drained into nothing on cold launch — didBecomeActive fires
            // well before Flutter's first frame — which is why a Start 5 from
            // the home screen opened the app and then sat there.
            dartIsListening = true
            drainPendingAction()
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
        // Park it, then drain — never park *and* send.
        //
        // A tap on a widget cold-launches the app, and this runs before Dart
        // is listening on the channel. Parked, it is drained by Dart's `ready`.
        // Sending it as well delivered it twice: Flutter buffers the last
        // message sent to a channel with no handler and replays it to the
        // first one installed, and the parked copy then drained on `ready` —
        // and a Start 5 route handled twice, before the first start has
        // landed, starts two sessions. With the app already running the drain
        // delivers it at once, and nothing is left parked for the next
        // foreground (now drained on scene activation too) to deliver again.
        defaults?.set(route, forKey: Self.pendingRouteKey)
        drainPendingAction()
        return true
    }

    /// Replay a press taken on a surface while the app was not listening.
    ///
    /// Called on every foreground: the intents behind Freeze and Start 5 run in
    /// the extension and cannot reach into the session themselves, so they leave
    /// the press here for the app to find.
    func drainPendingAction() {
        // Nothing is consumed until there is somewhere for it to land. Without
        // this the parked press is removed and invoked into a channel with no
        // handler, and it is gone for good.
        guard dartIsListening, let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
        // Route first: a widget that both starts five minutes and shows the
        // timer should not land on the timer before the session exists.
        if let route = defaults.string(forKey: Self.pendingRouteKey) {
            defaults.removeObject(forKey: Self.pendingRouteKey)
            channel.invokeMethod("route", arguments: route)
        }
        if let action = defaults.string(forKey: "ambient_pending_action") {
            defaults.removeObject(forKey: "ambient_pending_action")
            channel.invokeMethod("action", arguments: action)
        }
    }

    // MARK: - Shared container

    private static let appGroup = "group.com.r13.aqademiq.shared"
    private static let stateKey = "ambient_state"
    private static let pendingRouteKey = "ambient_pending_route"

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
        // The watch cannot see the container, so it is told. Same object, same
        // moment — there is no second schema and no second decision about when
        // a surface is stale.
        watch.push(json)
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
        // Silence here would be indistinguishable from a bug: an activity that
        // never appears looks identical whether the user turned Live Activities
        // off, the payload was malformed, or the code is wrong. Say which.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("Ambient: Live Activities are switched off for this app — nothing to show.")
            return
        }
        guard let state = contentState(args) else {
            NSLog("Ambient: session payload had no usable end instant — not starting an activity.")
            return
        }

        let attributes = FocusActivityAttributes(
            taskTitle: args["taskTitle"] as? String ?? "Focus session",
            subjectLabel: args["subjectLabel"] as? String,
            subjectTint: args["subjectTint"] as? String
        )

        do {
            let activity: Activity<FocusActivityAttributes>
            if #available(iOS 16.2, *) {
                // With a stale date, so a card the app never got to end (it
                // was not running at the end) says so rather than sitting at
                // 0:00 with a Freeze button for hours.
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: state.staleAt),
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            currentActivityID = activity.id
            NSLog("Ambient: Live Activity started (\(activity.id)).")
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
        // Live ones only. An ended activity stays listed until it is
        // dismissed — the last session's "Session done" card lingers for
        // minutes — and updating that would leave this session with nothing.
        let live = Activity<FocusActivityAttributes>.activities.filter { Self.isLive($0) }
        guard let activity = live.first(where: { $0.id == currentActivityID }) ?? live.first
        else {
            // Nothing on screen to update — the session outlived its activity
            // (an app restart, usually), so put one back.
            startActivity(args)
            return
        }
        if #available(iOS 16.2, *) {
            Task { await activity.update(ActivityContent(state: state, staleDate: state.staleAt)) }
        } else {
            Task { await activity.update(using: state) }
        }
        #endif
    }

    /// How long the lock screen keeps the "Session done" card. Long enough to
    /// be seen on the next glance at a phone left on the desk, short enough
    /// that it is a moment rather than a fixture. Ambient: ending never alerts.
    private static let doneLinger: TimeInterval = 5 * 60

    /// Stand the activity down.
    ///
    /// With `focusedSec` (a session that ran to its end), each activity still
    /// live is ended — one update, not a push per second — with its final
    /// content marked done, and left on the lock screen for `doneLinger`. The
    /// system takes an ended activity out of the Island at once, so the Island
    /// is still for a running session and nothing else. Without it, or for an
    /// activity the extension already ended (End on the lock screen), it goes
    /// immediately. A new session starting replaces a lingering card at once,
    /// through `startActivity`.
    private func endActivity(focusedSec: Int? = nil) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        currentActivityID = nil
        for activity in Activity<FocusActivityAttributes>.activities {
            // Stale counts as live here: a session that ran to its end while
            // its card had gone stale still earns the done card.
            guard let focusedSec, Self.isLive(activity) else {
                Task { await activity.end(dismissalPolicy: .immediate) }
                continue
            }
            let linger = ActivityUIDismissalPolicy.after(Date().addingTimeInterval(Self.doneLinger))
            if #available(iOS 16.2, *) {
                let doneContent = Self.doneState(activity.content.state, focusedSec: focusedSec)
                Task {
                    await activity.end(ActivityContent(state: doneContent, staleDate: nil),
                                       dismissalPolicy: linger)
                }
            } else {
                let doneContent = Self.doneState(activity.contentState, focusedSec: focusedSec)
                Task { await activity.end(using: doneContent, dismissalPolicy: linger) }
            }
        }
        #endif
    }

    #if canImport(ActivityKit)
    /// Still running as far as ActivityKit is concerned: active, or past its
    /// stale date (16.2+) but not ended. An ended activity — the done card
    /// lingering on the lock screen — is not.
    @available(iOS 16.1, *)
    private static func isLive(_ activity: Activity<FocusActivityAttributes>) -> Bool {
        if activity.activityState == .active { return true }
        if #available(iOS 16.2, *) { return activity.activityState == .stale }
        return false
    }

    /// The final content of a session that ran to its end: done, not held,
    /// and the time spent as what the card reads ("25:00 focused").
    @available(iOS 16.1, *)
    private static func doneState(
        _ current: FocusActivityAttributes.ContentState,
        focusedSec: Int
    ) -> FocusActivityAttributes.ContentState {
        var state = current
        state.done = true
        state.frozen = false
        state.remainingSec = max(0, state.durationSec - max(0, focusedSec))
        return state
    }

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
