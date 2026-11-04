import CryptoKit
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Everything App freeze keeps on the phone, and the one place it is applied.
///
/// The App Group is the only thing the app and its three extensions share, so
/// every hand-off goes through here (APP_FREEZE.md §5):
///
///  * `fz.policy` — the policy JSON exactly as Dart sent it;
///  * `fz.sel.<id>` — a `FamilyActivitySelection` from Apple's picker, as JSON;
///  * `fz.tok.<id>` — the token behind an id we gave Dart (grant targets);
///  * `fz.events` — what the shield did while Aqademiq was not looking (§1.2);
///  * `fz.shield.<day>` — how often the shield covered each app this thaw day;
///  * `fz.lastShield` — the app behind the last category shield (see `noteShield`);
///  * `fz.sched`, `fz.bounds` — what `FreezeSchedule` last asked iOS for.
///
/// Nothing here leaves the phone, and nothing in it is a name: iOS only ever
/// hands us opaque tokens ("We never see your picks").
enum FreezeStore {
    static let appGroup = "group.com.r13.aqademiq.shared"

    static let policyKey = "fz.policy"
    static let eventsKey = "fz.events"
    static let selectionPrefix = "fz.sel."
    static let tokenPrefix = "fz.tok."
    static let shieldPrefix = "fz.shield."
    static let lastShieldKey = "fz.lastShield"
    static let scheduleKey = "fz.sched"
    static let boundariesKey = "fz.bounds"

    /// The event type the shield's Thaw queues (§1.2).
    static let thawRequest = "thaw_request"

    /// Token id kinds: `app_…`, `cat_…`, `web_…`. Dart treats ids as opaque.
    static let appKind = "app"
    static let categoryKind = "cat"
    static let webKind = "web"

    /// How many events wait at most; older ones are dropped first.
    static let maxEvents = 50

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    // MARK: - Policy

    static func savePolicy(_ json: String) {
        defaults?.set(json, forKey: policyKey)
    }

    static func loadPolicy() -> FreezePolicy? {
        guard let raw = defaults?.string(forKey: policyKey) else { return nil }
        return FreezePolicy.decode(raw)
    }

    // MARK: - Events

    static func queueEvent(type: String, target: String?, at: Date = Date()) {
        guard let d = defaults else { return }
        var queue = d.array(forKey: eventsKey) as? [[String: Any]] ?? []
        var event: [String: Any] = ["type": type, "at": NSNumber(value: FreezeTime.ms(at))]
        if let target { event["target"] = target }
        queue.append(event)
        if queue.count > maxEvents { queue.removeFirst(queue.count - maxEvents) }
        d.set(queue, forKey: eventsKey)
    }

    static func hasEvents() -> Bool {
        !(defaults?.array(forKey: eventsKey)?.isEmpty ?? true)
    }

    /// The queued events, oldest first, in the shape `takeEvents` returns.
    /// Reading them clears them.
    static func takeEvents() -> [[String: Any]] {
        guard let d = defaults else { return [] }
        let raw = d.array(forKey: eventsKey) as? [[String: Any]] ?? []
        d.removeObject(forKey: eventsKey)
        return raw.compactMap { e -> [String: Any]? in
            guard let type = e["type"] as? String else { return nil }
            var out: [String: Any] = ["type": type]
            if let at = e["at"] as? NSNumber { out["at"] = NSNumber(value: at.int64Value) }
            if let target = e["target"] as? String { out["target"] = target }
            if let label = e["label"] as? String { out["label"] = label }
            return out
        }
    }

    // MARK: - Shield counts

    /// Counts one more cover of `id` in the current thaw day and returns the
    /// new count. Earlier days are dropped the first time a new one is used.
    @discardableResult
    static func bumpShieldCount(_ id: String, at t: Date = Date()) -> Int {
        let key = shieldPrefix + FreezeTime.dayString(FreezeRules.thawDayStart(t))
        guard let d = defaults else { return 1 }
        if d.object(forKey: key) == nil {
            for old in d.dictionaryRepresentation().keys where old.hasPrefix(shieldPrefix) && old != key {
                d.removeObject(forKey: old)
            }
        }
        var counts = d.dictionary(forKey: key) as? [String: Int] ?? [:]
        let n = (counts[id] ?? 0) + 1
        counts[id] = n
        d.set(counts, forKey: key)
        return n
    }

    // MARK: - Selections

    @available(iOS 16.0, *)
    static func selection(_ id: String?) -> FamilyActivitySelection? {
        guard let data = selectionData(id) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    @available(iOS 16.0, *)
    @discardableResult
    static func saveSelection(_ selection: FamilyActivitySelection, id: String) -> Bool {
        guard let d = defaults, let data = try? JSONEncoder().encode(selection) else { return false }
        d.set(data, forKey: selectionPrefix + id)
        return true
    }

    static func selectionData(_ id: String?) -> Data? {
        guard let id, !id.isEmpty else { return nil }
        return defaults?.data(forKey: selectionPrefix + id)
    }

    static func deleteSelection(_ id: String) {
        defaults?.removeObject(forKey: selectionPrefix + id)
    }

    // MARK: - Token ids

    /// A stable id for a token: its kind and a hash of its JSON encoding. The
    /// encoding itself is kept under `fz.tok.<id>` so a grant naming the id can
    /// be turned back into the token. The hash only has to tell apps apart on
    /// this phone — membership is still decided by token equality, never by id.
    static func tokenId<T: Encodable>(_ token: T, kind: String) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(token) else { return nil }
        let id = "\(kind)_\(digest(data, bytes: 10))"
        if let d = defaults, d.data(forKey: tokenPrefix + id) == nil {
            d.set(data, forKey: tokenPrefix + id)
        }
        return id
    }

    @available(iOS 16.0, *)
    static func resolve(_ id: String) -> FreezeTarget? {
        guard let data = defaults?.data(forKey: tokenPrefix + id) else { return nil }
        let decoder = JSONDecoder()
        if id.hasPrefix(appKind + "_"), let token = try? decoder.decode(ApplicationToken.self, from: data) {
            return .app(token)
        }
        if id.hasPrefix(categoryKind + "_"), let token = try? decoder.decode(ActivityCategoryToken.self, from: data) {
            return .category(token)
        }
        if id.hasPrefix(webKind + "_"), let token = try? decoder.decode(WebDomainToken.self, from: data) {
            return .webDomain(token)
        }
        return nil
    }

    /// Hex SHA-256 of `data`, cut to `bytes`.
    static func digest(_ data: Data, bytes: Int = 16) -> String {
        SHA256.hash(data: data).prefix(bytes).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - The app behind a category shield

    /// How long the note below stays good. A shield is pressed seconds after it
    /// is drawn; anything older belongs to some other open.
    static let lastShieldLifetime: TimeInterval = 10 * 60

    /// When a category shields an app, ShieldAction is handed only the
    /// category's token, but ShieldConfiguration — which runs first, to draw the
    /// shield — is handed the app's too. It notes the pair here so a Thaw names
    /// the app rather than thawing its whole category.
    @available(iOS 16.0, *)
    static func noteShield(app: ApplicationToken, category: ActivityCategoryToken, at t: Date = Date()) {
        guard let appId = tokenId(app, kind: appKind), let categoryId = tokenId(category, kind: categoryKind) else { return }
        let note: [String: Any] = ["app": appId, "cat": categoryId, "at": NSNumber(value: FreezeTime.ms(t))]
        defaults?.set(note, forKey: lastShieldKey)
    }

    /// The app id noted for `categoryId`, if the note is recent.
    static func lastShieldedApp(inCategory categoryId: String, at t: Date = Date()) -> String? {
        guard
            let note = defaults?.dictionary(forKey: lastShieldKey),
            note["cat"] as? String == categoryId,
            let app = note["app"] as? String,
            let at = note["at"] as? NSNumber
        else { return nil }
        let age = t.timeIntervalSince(FreezeTime.date(ms: at.int64Value))
        return age >= -60 && age <= lastShieldLifetime ? app : nil
    }

    // MARK: - Schedule bookkeeping

    /// Activity name → a signature of the schedule it was started with.
    static func scheduleSignatures() -> [String: String] {
        defaults?.dictionary(forKey: scheduleKey) as? [String: String] ?? [:]
    }

    static func saveScheduleSignatures(_ signatures: [String: String]) {
        defaults?.set(signatures, forKey: scheduleKey)
    }

    /// Activity name → when its interval really ends (ms), for one-off activities.
    static func boundaries() -> [String: Int64] {
        let raw = defaults?.dictionary(forKey: boundariesKey) ?? [:]
        var out: [String: Int64] = [:]
        for (key, value) in raw {
            if let n = value as? NSNumber { out[key] = n.int64Value }
        }
        return out
    }

    static func saveBoundaries(_ boundaries: [String: Int64]) {
        defaults?.set(boundaries.mapValues { NSNumber(value: $0) }, forKey: boundariesKey)
    }
}

/// Selections read once per evaluation: one rule pass can ask for the same
/// selection several times, and each read is a decode.
@available(iOS 16.0, *)
final class FreezeSelections {
    private var cache: [String: FamilyActivitySelection?] = [:]

    func get(_ id: String?) -> FamilyActivitySelection? {
        guard let id, !id.isEmpty else { return nil }
        if let hit = cache[id] { return hit }
        let read = FreezeStore.selection(id)
        cache.updateValue(read, forKey: id)
        return read
    }
}

/// Rewrites the shield for a moment. Every callback — the app, the monitor,
/// a press in the picker — ends here, so there is one way the shield gets set.
@available(iOS 16.0, *)
enum FreezeApply {
    static let storeName = "aqademiq.freeze"

    /// ManagedSettings shields at most 50 apps by token; past that it ignores
    /// the set. Never open goes first so it is the last thing to be cut.
    static let maxShieldedApps = 50

    static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(storeName))
    }

    /// Evaluates §2 at `date` and writes the result to the one store. No policy
    /// (never set up, or the App Group was wiped) clears it.
    static func applyNow(date: Date = Date()) {
        let store = self.store
        guard let policy = FreezeStore.loadPolicy() else {
            store.clearAllSettings()
            return
        }
        let selections = FreezeSelections()
        let plan = FreezeRules.shieldPlan(policy, at: date, selection: selections.get, resolve: FreezeStore.resolve)

        var apps = plan.applications
        if apps.count > maxShieldedApps {
            var capped = Set(plan.neverApplications.prefix(maxShieldedApps))
            for token in apps where capped.count < maxShieldedApps {
                capped.insert(token)
            }
            apps = capped
        }
        store.shield.applications = apps.isEmpty ? nil : apps

        if let except = plan.allCategoriesExcept {
            store.shield.applicationCategories = .all(except: except)
        } else if !plan.categories.isEmpty {
            store.shield.applicationCategories = .specific(plan.categories, except: plan.categoryExcept)
        } else {
            store.shield.applicationCategories = nil
        }

        store.shield.webDomains = plan.webDomains.isEmpty ? nil : plan.webDomains
        if plan.webCategories.isEmpty {
            store.shield.webDomainCategories = nil
        } else {
            store.shield.webDomainCategories = .specific(plan.webCategories, except: plan.webCategoryExcept)
        }

        if plan.adultFilter {
            // `.auto()`: the system's own adult-content filter, nothing added
            // or excepted. Spelled out so it does not lean on default arguments.
            store.webContent.blockedByFilter = .auto([], except: [])
        } else {
            store.webContent.blockedByFilter = nil
        }
    }
}

/// The two notifications App freeze posts. Both are local and immediate.
enum FreezeNotify {
    static let thawId = "fz.thaw"
    static let checkInId = "fz.checkin"

    /// The shield's Thaw. ShieldAction cannot open an app, so it asks the
    /// student to — the tap opens Aqademiq, which takes the breath and thaws.
    /// Time-sensitive: a study Focus is exactly when this is pressed, and it is
    /// a reply to a button, not a nudge.
    static func thawReady(completion: @escaping () -> Void) {
        post(
            id: thawId,
            title: "Thaw in Aqademiq",
            body: "Tap to take your breath, then it opens.",
            sound: true,
            timeSensitive: true,
            completion: completion
        )
    }

    /// Ada's check-in when a Distracting app has had ten minutes (§6). Never a
    /// count, never guilt — and no sound.
    static func checkIn(completion: (() -> Void)? = nil) {
        post(
            id: checkInId,
            title: "Ada",
            body: "Quick check-in — is this what you meant to open?",
            sound: false,
            timeSensitive: false,
            completion: completion
        )
    }

    private static func post(
        id: String,
        title: String,
        body: String,
        sound: Bool,
        timeSensitive: Bool,
        completion: (() -> Void)?
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        // Marks it as ours for anyone reading the tap; flutter_local_notifications
        // ignores notifications it did not schedule.
        content.userInfo = ["aqademiq": "freeze", "kind": id]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = timeSensitive ? .timeSensitive : .active
        }
        // Same id each time: a second press replaces the first banner rather
        // than stacking two.
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { NSLog("App freeze: notification \(id) failed — \(error.localizedDescription)") }
            completion?()
        }
    }
}
