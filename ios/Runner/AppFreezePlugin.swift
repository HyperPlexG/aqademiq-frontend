import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit
import UserNotifications

/// The iOS half of `aqademiq/app_freeze` (APP_FREEZE.md §1).
///
/// Screen Time does the freezing; this plugin only hands it the policy. The
/// rules live in `ios/FreezeShared/`, compiled into the app and into the three
/// extensions — FreezeMonitor (the schedule), FreezeShield (what the frozen
/// screen says) and FreezeShieldAction (its buttons) — because a frost has to
/// keep running, and the shield has to keep talking, while Aqademiq is closed.
///
/// Screen Time for the phone's own user (individual authorization) needs iOS
/// 16. The app's own floor stays at 13, so every call is availability-gated: below 16,
/// `status` answers `supported: false` and the rest are harmless no-ops. The
/// three frameworks are weak-linked so the app still launches on 13–15.
///
/// iOS never tells an app which apps were picked — only opaque tokens, saved
/// in the App Group. That is why `installedApps`, `appIcon` and `floorApps`
/// answer empty here: there is nothing to list, and Phone and emergency calls
/// are never shieldable, so iOS needs no floor.
final class AppFreezePlugin: NSObject {
    static let channelName = "aqademiq/app_freeze"

    private let channel: FlutterMethodChannel
    private var observers: [NSObjectProtocol] = []

    /// Both `UIApplication.didBecomeActive` and `UIScene.didActivate` arrive on
    /// a foreground; one pass is enough.
    private var lastActive = Date.distantPast

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return result(nil) }
            self.handle(call, result: result)
        }
        // Observed here rather than forwarded from AppDelegate, so it works the
        // same under the scene lifecycle.
        let center = NotificationCenter.default
        for name in [UIApplication.didBecomeActiveNotification, UIScene.didActivateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.didBecomeActive()
            })
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "status":
            status(result)
        case "requestAuthorization":
            requestAuthorization(result)
        case "openSettings":
            // iOS has one settings page an app can open: its own.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            result(nil)
        case "pickApps":
            pickApps(args, result: result)
        case "deleteSelection":
            if let id = args["selection_id"] as? String { FreezeStore.deleteSelection(id) }
            result(nil)
        case "installedApps":
            result([Any]())
        case "appIcon":
            result(nil)
        case "floorApps":
            result([String: String]())
        case "applyPolicy":
            applyPolicy(args, result: result)
        case "takeEvents":
            result(FreezeStore.takeEvents())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// §1.1. `usage_access` and `overlay` are Android's two grants; on iOS the
    /// one Screen Time approval stands for both.
    private func status(_ result: @escaping FlutterResult) {
        let supported: Bool
        let authorized: Bool
        if #available(iOS 16.0, *) {
            supported = true
            authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } else {
            supported = false
            authorized = false
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let notifications = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            DispatchQueue.main.async {
                result([
                    "supported": supported,
                    "authorized": authorized,
                    "usage_access": authorized,
                    "overlay": authorized,
                    "battery_restricted": false,
                    "notifications": notifications,
                ])
            }
        }
    }

    /// The one Screen Time ask, for this phone's own user (`.individual`), not
    /// a child in a Family Sharing group.
    private func requestAuthorization(_ result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else { return result(false) }
        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                NSLog("App freeze: Screen Time authorization failed — \(error.localizedDescription)")
            }
            let approved = AuthorizationCenter.shared.authorizationStatus == .approved
            // A policy saved before approval could not be scheduled; now it can.
            if approved, FreezeStore.loadPolicy() != nil {
                FreezeApply.applyNow()
                FreezeSchedule.reschedule()
            }
            result(approved)
        }
    }

    /// Stores the policy, re-shields for now, and reschedules the wake-ups that
    /// keep it running with the app closed.
    private func applyPolicy(_ args: [String: Any], result: @escaping FlutterResult) {
        guard let json = args["policy"] as? String else {
            return result(FlutterError(code: "bad_args", message: "policy missing", details: nil))
        }
        // Checked before saving: a policy that is not JSON would otherwise
        // replace a good one and clear every shield.
        guard FreezePolicy.decode(json) != nil else {
            return result(FlutterError(code: "bad_policy", message: "policy is not a JSON object", details: nil))
        }
        FreezeStore.savePolicy(json)
        if #available(iOS 16.0, *) {
            FreezeApply.applyNow()
            FreezeSchedule.reschedule()
        }
        result(nil)
    }

    // MARK: - Foreground

    /// Every foreground: re-apply (cheap, and it heals a shield the monitor
    /// missed), and tell Dart about thaw requests the shield queued while the
    /// app was away. The queue is not consumed here — on a cold launch Dart is
    /// not listening yet, so the events wait for its own `takeEvents`.
    private func didBecomeActive() {
        let now = Date()
        guard now.timeIntervalSince(lastActive) > 1 else { return }
        lastActive = now
        if #available(iOS 16.0, *), AuthorizationCenter.shared.authorizationStatus == .approved, FreezeStore.loadPolicy() != nil {
            FreezeApply.applyNow(date: now)
            FreezeSchedule.reschedule(now: now)
        }
        if FreezeStore.hasEvents() {
            channel.invokeMethod("eventsWaiting", arguments: nil)
        }
    }

    // MARK: - Picker

    /// Apple's FamilyActivityPicker over the app, preloaded with what was
    /// picked last time. Done saves the selection under `selection_id` and
    /// answers `{count}`; Cancel answers nil.
    private func pickApps(_ args: [String: Any], result: @escaping FlutterResult) {
        guard #available(iOS 16.0, *) else { return result(nil) }
        guard let id = args["selection_id"] as? String, !id.isEmpty else {
            return result(FlutterError(code: "bad_args", message: "selection_id missing", details: nil))
        }
        let title = (args["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Choose apps"
        Task { @MainActor in
            // The picker shows nothing without approval, so ask first.
            if AuthorizationCenter.shared.authorizationStatus != .approved {
                try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            }
            guard AuthorizationCenter.shared.authorizationStatus == .approved else {
                result(nil)
                return
            }
            self.presentPicker(id: id, title: title, result: result)
        }
    }

    @available(iOS 16.0, *)
    private func presentPicker(id: String, title: String, result: @escaping FlutterResult) {
        guard let presenter = Self.topViewController() else {
            result(nil)
            return
        }
        let initial = FreezeStore.selection(id) ?? FamilyActivitySelection()
        var finished = false
        weak var host: UIViewController?
        let finish: (FamilyActivitySelection?) -> Void = { picked in
            guard !finished else { return }
            finished = true
            if let picked, FreezeStore.saveSelection(picked, id: id) {
                // The selection may belong to a frost running now.
                FreezeApply.applyNow()
                FreezeSchedule.reschedule()
                let count = picked.applicationTokens.count + picked.categoryTokens.count + picked.webDomainTokens.count
                result(["count": count])
            } else {
                result(nil)
            }
            host?.dismiss(animated: true)
        }
        let picker = FreezePickerView(
            title: title,
            selection: initial,
            onCancel: { finish(nil) },
            onDone: { finish($0) }
        )
        let controller = UIHostingController(rootView: picker)
        // No swipe-to-dismiss: every way out goes through Cancel or Done, so
        // Dart always gets an answer.
        controller.isModalInPresentation = true
        host = controller
        presenter.present(controller, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// The picker sheet: Apple's FamilyActivityPicker with a title, Cancel and Done.
@available(iOS 16.0, *)
private struct FreezePickerView: View {
    let title: String
    @State private var selection: FamilyActivitySelection
    let onCancel: () -> Void
    let onDone: (FamilyActivitySelection) -> Void

    init(
        title: String,
        selection: FamilyActivitySelection,
        onCancel: @escaping () -> Void,
        onDone: @escaping (FamilyActivitySelection) -> Void
    ) {
        self.title = title
        _selection = State(initialValue: selection)
        self.onCancel = onCancel
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone(selection) }
                    }
                }
        }
    }
}
