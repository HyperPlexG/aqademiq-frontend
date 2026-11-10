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
/// are never shieldable, so iOS needs no floor. What the app *can* do is ask
/// FamilyControls to draw a token for it (`FreezeTokenViewFactory`, below):
/// Dart gets token ids from `selectionTokens` and shows each one in a
/// platform view, so the icons appear without the app ever learning a name.
final class AppFreezePlugin: NSObject {
    static let channelName = "aqademiq/app_freeze"

    /// The platform view that draws one token (`FreezeTokenViewFactory`).
    static let tokenViewType = "aqademiq/fz_token"

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

    /// Whether this build carries the Family Controls entitlement.
    ///
    /// iOS gives an app no way to read its own entitlements, so the build says
    /// it in Info.plist: `AQAppFreezeEnabled` is false in the checked-in file
    /// and `ios/add_freeze_targets.rb` sets it true when it adds the
    /// entitlement. Without it Screen Time refuses every call, so `status`
    /// answers `supported: false` and the app hides App freeze rather than
    /// walking a student into a setup that cannot finish.
    static var entitled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "AQAppFreezeEnabled") as? Bool ?? false
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
        case "selectionTokens":
            result(Self.selectionTokens(args["selection_id"] as? String) ?? NSNull())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// §1.1. `usage_access` and `overlay` are Android's two grants; on iOS the
    /// one Screen Time approval stands for both.
    private func status(_ result: @escaping FlutterResult) {
        let supported: Bool
        let authorized: Bool
        if #available(iOS 16.0, *), Self.entitled {
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
        guard #available(iOS 16.0, *), Self.entitled else { return result(false) }
        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            } catch {
                NSLog("App freeze: Screen Time authorization failed — \(error.localizedDescription)")
            }
            let approved = AuthorizationCenter.shared.authorizationStatus == .approved
            // A policy saved before approval could not be scheduled; now it can.
            if approved { AppFreezePlugin.reapply(onlyIfSetUp: true) }
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
        // Saved whatever the authorization: approval later applies it.
        FreezeStore.savePolicy(json)
        Self.reapply()
        result(nil)
    }

    /// The token ids in a saved selection, for `aqademiq/fz_token` to draw:
    /// categories first (one stands for many apps), then apps, then sites,
    /// each kind sorted by id so the order is the same on every call (a
    /// `Set`'s order is not). nil where tokens cannot be drawn — below iOS 16
    /// or without the entitlement — so Dart falls back to the count. An
    /// unknown or empty selection is `[]`.
    ///
    /// The ids are the ones `thaw_request` uses (`FreezeStore.tokenId`, which
    /// also keeps the token under `fz.tok.<id>` for the view to resolve). They
    /// are hashes, never names, and they stay on the phone.
    static func selectionTokens(_ id: String?) -> [String]? {
        guard #available(iOS 16.0, *), entitled else { return nil }
        guard let selection = FreezeStore.selection(id) else { return [] }
        let categories = selection.categoryTokens.compactMap { FreezeStore.tokenId($0, kind: FreezeStore.categoryKind) }
        let apps = selection.applicationTokens.compactMap { FreezeStore.tokenId($0, kind: FreezeStore.appKind) }
        let sites = selection.webDomainTokens.compactMap { FreezeStore.tokenId($0, kind: FreezeStore.webKind) }
        return categories.sorted() + apps.sorted() + sites.sorted()
    }

    // MARK: - Applying

    /// One serial queue for every apply: ManagedSettings and DeviceActivity
    /// answer synchronously through Screen Time's daemons, which is no work
    /// for the main thread, and two applies in quick succession must land in
    /// the order they were asked for. Each reads the stored policy when it
    /// runs, so a queued one applies the newest.
    private static let applyQueue = DispatchQueue(label: "com.r13.aqademiq.freeze.apply", qos: .userInitiated)

    /// Re-shields and reschedules from the stored policy, off the main thread
    /// — and only with Screen Time approved: without it ManagedSettings and
    /// DeviceActivity refuse or ignore every call, and a policy saved now is
    /// applied once approval comes (`requestAuthorization`, or the next
    /// foreground). `onlyIfSetUp` skips it when no policy was ever stored.
    private static func reapply(onlyIfSetUp: Bool = false) {
        guard #available(iOS 16.0, *), AuthorizationCenter.shared.authorizationStatus == .approved else { return }
        applyQueue.async {
            if onlyIfSetUp && FreezeStore.loadPolicy() == nil { return }
            FreezeApply.applyNow()
            FreezeSchedule.reschedule()
        }
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
        Self.reapply(onlyIfSetUp: true)
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
                AppFreezePlugin.reapply()
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

// MARK: - Token view

/// `aqademiq/fz_token`: one app, category or site, drawn by FamilyControls.
///
/// Apple's `Label(token)` renders the icon and name inside the app's process
/// without handing either to the app, so this is how App freeze shows icons on
/// iOS at all. Creation args: `id` (a token id from `selectionTokens` or a
/// `thaw_request`), `style` (`icon` — the default — or `title`), and for a
/// title `font_size`, `weight` (100…900) and `color` (ARGB). An id that does
/// not resolve draws nothing, and Dart's placeholder tile shows through.
final class FreezeTokenViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        FreezeTokenPlatformView(frame: frame, args: args as? [String: Any] ?? [:])
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private final class FreezeTokenPlatformView: NSObject, FlutterPlatformView {
    /// Holds the SwiftUI host for as long as Flutter shows the view.
    private let host: UIViewController?
    private let root: UIView

    init(frame: CGRect, args: [String: Any]) {
        if #available(iOS 16.0, *),
           let id = args["id"] as? String,
           let target = FreezeStore.resolve(id) {
            let controller = UIHostingController(rootView: FreezeTokenLabel(target: target, style: FreezeTokenLabel.Style(args)))
            controller.view.backgroundColor = .clear
            controller.view.frame = frame
            // Touches belong to Flutter: a tile's tap is a Flutter gesture.
            controller.view.isUserInteractionEnabled = false
            host = controller
            root = controller.view
        } else {
            host = nil
            root = UIView(frame: frame)
            root.backgroundColor = .clear
            root.isUserInteractionEnabled = false
        }
        super.init()
    }

    func view() -> UIView { root }
}

@available(iOS 16.0, *)
private struct FreezeTokenLabel: View {
    enum Style {
        case icon
        case title(size: CGFloat, weight: Font.Weight, color: Color)

        init(_ args: [String: Any]) {
            guard args["style"] as? String == "title" else {
                self = .icon
                return
            }
            let size = (args["font_size"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 17
            let weight = Self.weight((args["weight"] as? NSNumber)?.intValue ?? 500)
            let argb = (args["color"] as? NSNumber)?.uint32Value ?? 0xFF1A_1320
            let color = Color(
                .sRGB,
                red: Double((argb >> 16) & 0xFF) / 255,
                green: Double((argb >> 8) & 0xFF) / 255,
                blue: Double(argb & 0xFF) / 255,
                opacity: Double((argb >> 24) & 0xFF) / 255
            )
            self = .title(size: size, weight: weight, color: color)
        }

        private static func weight(_ w: Int) -> Font.Weight {
            switch w {
            case ..<200: return .ultraLight
            case ..<300: return .thin
            case ..<400: return .light
            case ..<500: return .regular
            case ..<600: return .medium
            case ..<700: return .semibold
            case ..<800: return .bold
            case ..<900: return .heavy
            default: return .black
            }
        }
    }

    let target: FreezeTarget
    let style: Style

    var body: some View {
        switch style {
        case .icon:
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                FreezeFitted(side: side) {
                    label.labelStyle(.iconOnly).font(.system(size: max(side * 0.8, 1)))
                }
                // Apple's continuous corners: the same outline as Dart's
                // fzSquircle, clipped here so Flutter never clips a platform
                // view.
                .clipShape(RoundedRectangle(cornerRadius: side * 0.225, style: .continuous))
                .frame(width: geo.size.width, height: geo.size.height)
            }
        case let .title(size, weight, color):
            label
                .labelStyle(.titleOnly)
                .font(.system(size: size, weight: weight))
                .foregroundColor(color)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var label: some View {
        switch target {
        case let .app(token): Label(token)
        case let .category(token): Label(token)
        case let .webDomain(token): Label(token)
        }
    }
}

/// Scales its content to fill a `side` × `side` square, whatever size it
/// draws at on its own. FamilyControls does not document how big the icon of
/// a `Label(token)` is, so it is measured rather than assumed.
@available(iOS 16.0, *)
private struct FreezeFitted<Content: View>: View {
    let side: CGFloat
    @ViewBuilder let content: () -> Content
    @State private var natural: CGSize = .zero

    var body: some View {
        content()
            .fixedSize()
            .background(GeometryReader { g in
                Color.clear.preference(key: FreezeNaturalSize.self, value: g.size)
            })
            .onPreferenceChange(FreezeNaturalSize.self) { natural = $0 }
            .scaleEffect(scale)
            .frame(width: side, height: side)
    }

    private var scale: CGFloat {
        let m = max(natural.width, natural.height)
        return m > 0 && side > 0 ? side / m : 1
    }
}

private struct FreezeNaturalSize: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
