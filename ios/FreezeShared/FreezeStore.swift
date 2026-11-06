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
///  * `fz.lastCount` — the last app the shield was drawn for, and when, so one
///    appearance drawn twice is counted once (see `countShield`);
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
    static let lastCountKey = "fz.lastCount"
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
    /// Reading them takes them off the queue — those, and only those: the
    /// ShieldAction extension is another process and may queue one between
    /// the read and the write, and that one must wait for the next take
    /// rather than be wiped unread.
    static func takeEvents() -> [[String: Any]] {
        guard let d = defaults else { return [] }
        let raw = d.array(forKey: eventsKey) as? [[String: Any]] ?? []
        if !raw.isEmpty {
            var taken = raw.map { $0 as NSDictionary }
            let current = d.array(forKey: eventsKey) as? [[String: Any]] ?? []
            let rest = current.filter { event in
                let e = event as NSDictionary
                guard let i = taken.firstIndex(where: { $0.isEqual(e) }) else { return true }
                taken.remove(at: i)
                return false
            }
            if rest.isEmpty {
                d.removeObject(forKey: eventsKey)
            } else {
                d.set(rest, forKey: eventsKey)
            }
        }
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

    /// iOS can ask ShieldConfiguration for the same shield more than once —
    /// drawn again on returning to it, on a trait change — and each ask is
    /// not another time the student opened the app. Asks for the same id this
    /// close together are one appearance.
    static let shieldRepeatWindow: TimeInterval = 5

    /// The shield was drawn for `id`: counts it as one more cover this thaw
    /// day, unless the last draw was for the same id less than
    /// `shieldRepeatWindow` ago — then it is the same appearance and today's
    /// count is returned as it stands. Every draw moves the window on, so a
    /// burst of redraws counts once however long it lasts.
    static func countShield(_ id: String, at t: Date = Date()) -> Int {
        guard let d = defaults else { return 1 }
        var repeated = false
        if let last = d.dictionary(forKey: lastCountKey),
           last["id"] as? String == id,
           let at = last["at"] as? NSNumber {
            let age = t.timeIntervalSince(FreezeTime.date(ms: at.int64Value))
            repeated = age >= 0 && age < shieldRepeatWindow
        }
        d.set(["id": id, "at": NSNumber(value: FreezeTime.ms(t))] as [String: Any], forKey: lastCountKey)
        if repeated {
            let n = shieldCount(id, at: t)
            if n > 0 { return n }
        }
        return bumpShieldCount(id, at: t)
    }

    /// Today's count for `id`, without adding to it.
    static func shieldCount(_ id: String, at t: Date = Date()) -> Int {
        let key = shieldPrefix + FreezeTime.dayString(FreezeRules.thawDayStart(t))
        return (defaults?.dictionary(forKey: key) as? [String: Int])?[id] ?? 0
    }

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
        guard let data = tokenData(token) else { return nil }
        let id = "\(kind)_\(digest(data, bytes: 10))"
        if let d = defaults, d.data(forKey: tokenPrefix + id) == nil {
            d.set(data, forKey: tokenPrefix + id)
        }
        return id
    }

    /// A token's JSON encoding, keys sorted so the same token always gives
    /// the same bytes — in the app and in every extension.
    static func tokenData<T: Encodable>(_ token: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(token)
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
///
/// Three named stores, one per layer of `FreezeShieldPlan`: Never open, the
/// Deep freezes, and everything else. ManagedSettings shields whatever any
/// store shields, so a category policy's `except` in one store cannot open
/// what another holds — which is the whole point of the split.
@available(iOS 16.0, *)
enum FreezeApply {
    /// Everything but Never open and Deep freeze (the name from before the
    /// split, so an older build's settings are overwritten, not left behind).
    static let storeName = "aqademiq.freeze"
    static let neverStoreName = "aqademiq.freeze.never"
    static let deepStoreName = "aqademiq.freeze.deep"

    /// ManagedSettings shields at most 50 apps by token; past that it ignores
    /// the set. Kept to 50 across the three stores together: Never open is
    /// the last thing to be cut, then Deep freeze, then the rest.
    static let maxShieldedApps = 50

    static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(storeName))
    }

    static var neverStore: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(neverStoreName))
    }

    static var deepStore: ManagedSettingsStore {
        ManagedSettingsStore(named: ManagedSettingsStore.Name(deepStoreName))
    }

    /// Evaluates §2 at `date` and writes the result to the three stores. No
    /// policy (never set up, or the App Group was wiped) clears all three.
    static func applyNow(date: Date = Date()) {
        let main = store
        let never = neverStore
        let deep = deepStore
        guard let policy = FreezeStore.loadPolicy() else {
            main.clearAllSettings()
            never.clearAllSettings()
            deep.clearAllSettings()
            return
        }
        let selections = FreezeSelections()
        var plan = FreezeRules.shieldPlan(policy, at: date, selection: selections.get, resolve: FreezeStore.resolve)
        capApplications(&plan)

        write(plan.never, to: never)
        write(plan.deep, to: deep)
        write(plan.main, to: main)

        if plan.adultFilter {
            // `.auto()`: the system's own adult-content filter, nothing added
            // or excepted. Spelled out so it does not lean on default arguments.
            never.webContent.blockedByFilter = .auto([], except: [])
        } else {
            never.webContent.blockedByFilter = nil
        }
        // Only Never open filters the web. Cleared in the other two because
        // the main store carried the filter before the split.
        main.webContent.blockedByFilter = nil
        deep.webContent.blockedByFilter = nil
    }

    private static func write(_ layer: FreezeShieldLayer, to store: ManagedSettingsStore) {
        store.shield.applications = layer.applications.isEmpty ? nil : layer.applications

        if let except = layer.allCategoriesExcept {
            store.shield.applicationCategories = .all(except: except)
        } else if !layer.categories.isEmpty {
            store.shield.applicationCategories = .specific(layer.categories, except: layer.categoryExcept)
        } else {
            store.shield.applicationCategories = nil
        }

        store.shield.webDomains = layer.webDomains.isEmpty ? nil : layer.webDomains
        if layer.webCategories.isEmpty {
            store.shield.webDomainCategories = nil
        } else {
            store.shield.webDomainCategories = .specific(layer.webCategories, except: layer.webCategoryExcept)
        }
    }

    /// Holds the three stores' app tokens to `maxShieldedApps` together. An
    /// app is shielded in the first layer that has it — Never open, then
    /// Deep, then the rest — and only there: a store further down adds
    /// nothing for it, since neither of the first two can be thawed open.
    ///
    /// Which apps survive the cut is decided by a digest of each token's
    /// encoding, never by `Set` order: Swift seeds its hashing per process,
    /// so the app and the monitor extension would otherwise cut different
    /// apps and the shield would change with whichever wrote last.
    static func capApplications(_ plan: inout FreezeShieldPlan) {
        let all = plan.never.applications
            .union(plan.deep.applications)
            .union(plan.main.applications)
        guard all.count > maxShieldedApps else { return }
        var room = maxShieldedApps
        var taken = Set<ApplicationToken>()
        func keep(_ tokens: Set<ApplicationToken>) -> Set<ApplicationToken> {
            var out = Set<ApplicationToken>()
            for token in ordered(tokens.subtracting(taken)) {
                if room == 0 { break }
                out.insert(token)
                taken.insert(token)
                room -= 1
            }
            return out
        }
        plan.never.applications = keep(plan.never.applications)
        plan.deep.applications = keep(plan.deep.applications)
        plan.main.applications = keep(plan.main.applications)
    }

    /// `tokens` in a stable order: by the SHA-256 of their sorted-key JSON.
    static func ordered(_ tokens: Set<ApplicationToken>) -> [ApplicationToken] {
        let keyed = tokens.map { token -> (token: ApplicationToken, key: String) in
            let key = FreezeStore.tokenData(token).map { data in FreezeStore.digest(data) } ?? ""
            return (token: token, key: key)
        }
        return keyed.sorted { $0.key < $1.key }.map { $0.token }
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
