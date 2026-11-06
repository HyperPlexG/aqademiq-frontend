import FamilyControls
import Foundation
import ManagedSettings

// The App freeze rules (APP_FREEZE.md §2), ported from `freeze_engine.dart`.
//
// `FreezeEngine` in Dart is the specification; this file and `FreezeRules.kt`
// follow it, because a frost has to keep running while Aqademiq is closed and
// only native code is awake then. Change a rule there and change it here.
//
// Two layers:
//
//  * the rules themselves — `windowAt`, `standingDown`, `active`, `covers`,
//    `isFrozen`, the breath and the 4 AM thaw day — over plain values, exactly
//    as Dart writes them (no availability checks; Runner's floor is iOS 13);
//  * the translation into what iOS can actually be told, which is not "is this
//    app frozen" but ManagedSettings shields — app tokens, a category policy
//    and web domains, in three named stores (`shieldPlan`) — plus what the
//    shield should say about the app it is covering (`describe`). Tokens are
//    opaque, so that layer cannot ask which category an app is in — the
//    places where that makes iOS coarser than the rule are called out where
//    they happen.

/// One window of a frost: when it started, and when it ends (nil = until stopped).
struct FreezeWindow: Equatable {
    let start: Date
    let end: Date?
}

/// A freeze running now: a frost in its window, or Freeze now.
struct FreezeActive {
    /// The frost's id, or `FreezeRules.nowId`.
    let id: String
    let name: String
    let apps: FreezeAppSet
    let deep: Bool
    let start: Date
    let end: Date?
}

/// What the shield should say about the thing it covers (APP_FREEZE.md §4).
struct FreezeShieldInfo {
    /// In Never open: "Never open." and no thaw.
    var never = false
    /// Some running freeze covers it. False means the shield is stale (the
    /// store has not caught up with the policy yet).
    var covered = false
    /// A Deep freeze is among what covers it: no thaw button.
    var deep = false
    /// When it unfreezes: the latest end among the freezes covering it; nil
    /// when any of them has no end ("Until you stop").
    var until: Date?
    /// The same over the Deep freezes covering it: when thawing opens again.
    var deepUntil: Date?
    /// The breath before a thaw, in seconds.
    var breath = FreezeRules.breathSeconds
}

enum FreezeRules {
    /// The id Freeze now goes by in `active` and in stand-down holds.
    static let nowId = "now"

    /// A grant target meaning every app (Thaw all).
    static let allApps = "*"

    /// Thaws count per day, and a day starts at 4 AM — a thaw at 1 AM still
    /// counts against last night.
    static let dayStartHour = 4

    /// Standard resistance, and the first thaw of the day on Increasing.
    static let breathSeconds = 10
    /// Increasing adds this per thaw already taken today, up to `maxBreath`.
    static let breathStep = 10
    static let maxBreath = 60

    // MARK: - Windows

    static func inDates(_ f: FreezeFrost, _ day: Date) -> Bool {
        let d = FreezeTime.dayKey(day)
        if let from = f.fromKey, d < from { return false }
        if let until = f.untilKey, d > until { return false }
        return true
    }

    /// The window of `f` that contains `t`, ignoring whether the frost is on,
    /// skipped or standing down.
    static func windowAt(_ f: FreezeFrost, _ t: Date) -> FreezeWindow? {
        if f.isSession {
            guard let started = f.sessionStart, t >= started else { return nil }
            let end = f.sessionMinutes.map { started.addingTimeInterval(TimeInterval($0) * 60) }
            if let end, t >= end { return nil }
            return FreezeWindow(start: started, end: end)
        }
        let today = FreezeTime.dayStart(t)
        let minute = FreezeTime.minuteOfDay(t)
        if !f.overnight {
            let end = f.allDay ? 1440 : f.end
            if f.days.contains(FreezeTime.isoWeekday(t)), inDates(f, today), minute >= f.start, minute < end {
                return FreezeWindow(start: FreezeTime.at(today, f.start), end: FreezeTime.at(today, end))
            }
            return nil
        }
        // Overnight: tonight's window, or the tail of last night's.
        if f.days.contains(FreezeTime.isoWeekday(t)), inDates(f, today), minute >= f.start {
            return FreezeWindow(start: FreezeTime.at(today, f.start), end: FreezeTime.at(today, 1440 + f.end))
        }
        let yesterday = FreezeTime.addDays(today, -1)
        if f.days.contains(FreezeTime.isoWeekday(yesterday)), inDates(f, yesterday), minute < f.end {
            return FreezeWindow(start: FreezeTime.at(yesterday, f.start), end: FreezeTime.at(today, f.end))
        }
        return nil
    }

    /// When `f` next starts after `t`. Nil for a session frost, a frost with no
    /// days, or one whose dates have passed.
    static func nextStart(_ f: FreezeFrost, _ t: Date) -> Date? {
        if f.isSession || f.days.isEmpty { return nil }
        let today = FreezeTime.dayStart(t)
        for i in 0...400 {
            let day = FreezeTime.addDays(today, i)
            if let until = f.untilKey, FreezeTime.dayKey(day) > until { return nil }
            if !f.days.contains(FreezeTime.isoWeekday(day)) || !inDates(f, day) { continue }
            let start = FreezeTime.at(day, f.start)
            if start > t { return start }
        }
        return nil
    }

    // MARK: - What is running

    static func standingDown(_ p: FreezePolicy, _ t: Date) -> Bool {
        guard let s = p.standdown else { return false }
        return t >= s.sinceDate && (s.untilDate.map { t < $0 } ?? true)
    }

    /// Everything running at `t`. A frost that is off, skipped for today, or
    /// standing down (and not held) is not running.
    static func active(_ p: FreezePolicy, _ t: Date) -> [FreezeActive] {
        var out: [FreezeActive] = []
        let down = standingDown(p, t)
        let holds = p.standdown?.holdDates ?? [:]
        for f in p.frosts {
            if !f.enabled { continue }
            if let skip = f.skipUntilDate, t < skip { continue }
            guard let w = windowAt(f, t) else { continue }
            if down {
                guard let hold = holds[f.id], t < hold else { continue }
            }
            out.append(FreezeActive(id: f.id, name: f.name, apps: f.apps, deep: f.deep, start: w.start, end: w.end))
        }
        if let now = p.now, t >= now.startedAtDate, now.endsAtDate.map({ t < $0 }) ?? true {
            var held = !down
            if down, let hold = holds[nowId] { held = t < hold }
            if held {
                out.append(FreezeActive(
                    id: nowId,
                    name: "Freeze now",
                    apps: now.apps,
                    deep: now.deep,
                    start: now.startedAtDate,
                    end: now.endsAtDate
                ))
            }
        }
        return out
    }

    /// `covers(source, app)`: Keep only covers every app it does not list.
    /// `contains` answers whether a set lists the app in question.
    static func covers(_ set: FreezeAppSet, _ contains: (FreezeAppSet) -> Bool) -> Bool {
        set.keepOnly ? !contains(set) : contains(set)
    }

    /// A thaw that covers `target` at `t`.
    static func grantFor(_ p: FreezePolicy, target: String, at t: Date) -> FreezeGrant? {
        p.grants.first { t < $0.untilDate && ($0.target == allApps || $0.target == target) }
    }

    /// The rule for one app, with app identity abstracted: `target` is what a
    /// grant would name it by, `contains` whether a set lists it. The token
    /// layer below is this same rule spread over a whole shield at once.
    static func isFrozen(_ p: FreezePolicy, target: String, at t: Date, contains: (FreezeAppSet) -> Bool) -> Bool {
        if contains(p.groups.neverOpen) { return true }
        if contains(p.groups.alwaysOpen) { return false }
        let covering = active(p, t).filter { covers($0.apps, contains) }
        if covering.isEmpty { return false }
        if covering.contains(where: { $0.deep }) { return true }
        return grantFor(p, target: target, at: t) == nil
    }

    // MARK: - Breath

    /// The start of the thaw day containing `t` (4 AM).
    static func thawDayStart(_ t: Date) -> Date {
        let today = FreezeTime.dayStart(t)
        let four = FreezeTime.at(today, dayStartHour * 60)
        return t < four ? FreezeTime.at(FreezeTime.addDays(today, -1), dayStartHour * 60) : four
    }

    /// `thaws_today` if it was counted in the current thaw day, otherwise 0 —
    /// the same day, not merely "since this day began": a count stamped in
    /// the future (a clock set back) says nothing about today either.
    static func thawsToday(_ p: FreezePolicy, at t: Date) -> Int {
        guard let counted = p.thawsCountedAtDate, thawDayStart(counted) == thawDayStart(t) else { return 0 }
        return max(p.thawsToday, 0)
    }

    /// 10 seconds, or on Increasing 10 more for each thaw already taken today,
    /// up to a minute.
    static func breath(_ p: FreezePolicy, at t: Date) -> Int {
        guard p.thaw.increasing else { return breathSeconds }
        return min(breathSeconds + breathStep * thawsToday(p, at: t), maxBreath)
    }
}

// MARK: - Tokens

/// What a grant target id stands for once the App Group has decoded it.
@available(iOS 16.0, *)
enum FreezeTarget {
    case app(ApplicationToken)
    case category(ActivityCategoryToken)
    case webDomain(WebDomainToken)
}

/// Everything a running thaw opens.
@available(iOS 16.0, *)
struct FreezeThawed {
    /// A `*` grant: every source that is not deep stands aside.
    var all = false
    var apps = Set<ApplicationToken>()
    var categories = Set<ActivityCategoryToken>()
    var webDomains = Set<WebDomainToken>()
}

/// One `ManagedSettingsStore`'s shield, as ManagedSettings takes it.
@available(iOS 16.0, *)
struct FreezeShieldLayer {
    var applications = Set<ApplicationToken>()
    /// `.specific(categories, except: categoryExcept)`, unless a Keep only
    /// source is running in this layer, which makes it
    /// `.all(except: allCategoriesExcept)`.
    var categories = Set<ActivityCategoryToken>()
    var categoryExcept = Set<ApplicationToken>()
    var allCategoriesExcept: Set<ApplicationToken>?
    var webDomains = Set<WebDomainToken>()
    var webCategories = Set<ActivityCategoryToken>()
    var webCategoryExcept = Set<WebDomainToken>()

    mutating func add(apps: Set<ApplicationToken>, categories: Set<ActivityCategoryToken>, webDomains: Set<WebDomainToken>) {
        applications.formUnion(apps)
        self.categories.formUnion(categories)
        webCategories.formUnion(categories)
        self.webDomains.formUnion(webDomains)
    }

    /// With two Keep only sources in one layer, an app stays open only if
    /// both keep it.
    mutating func keep(_ open: Set<ApplicationToken>) {
        allCategoriesExcept = allCategoriesExcept.map { $0.intersection(open) } ?? open
    }
}

/// The shield, as three named stores. A category policy's `except` reaches
/// every category in its store, so what may never be excepted lives in a
/// store of its own; ManagedSettings shields whatever any one store shields.
///
///  * `never` — Never open, alone, with no `except` at all: not Always open,
///    not a thaw, not a stand-down reaches it.
///  * `deep` — the running Deep freezes. Always open is excepted (rule 2
///    beats every frost); a thaw never is.
///  * `main` — every other running freeze, with Always open and the running
///    thaws excepted.
@available(iOS 16.0, *)
struct FreezeShieldPlan {
    var never = FreezeShieldLayer()
    var deep = FreezeShieldLayer()
    var main = FreezeShieldLayer()
    /// Never open → Adult sites: `webContent.blockedByFilter = .auto()`, in
    /// the `never` store.
    var adultFilter = false
}

@available(iOS 16.0, *)
extension FreezeRules {
    /// The running thaws at `t`, with their targets decoded.
    static func thawed(_ p: FreezePolicy, at t: Date, resolve: (String) -> FreezeTarget?) -> FreezeThawed {
        var out = FreezeThawed()
        for g in p.grants where t < g.untilDate {
            if g.target == allApps {
                out.all = true
                continue
            }
            switch resolve(g.target) {
            case .app(let token)?: out.apps.insert(token)
            case .category(let token)?: out.categories.insert(token)
            case .webDomain(let token)?: out.webDomains.insert(token)
            case nil: break
            }
        }
        return out
    }

    /// §2's `isFrozen`, over every token at once, spread over three stores
    /// (`FreezeShieldPlan`) because a category policy's `except` reaches every
    /// category in its store.
    ///
    /// 1. Never open goes in its own store, with nothing excepted — not Always
    ///    open, not a stand-down, not a thaw.
    /// 2. Always open is subtracted from every frost, Deep ones included: its
    ///    apps from the token sets and from every category policy's `except`,
    ///    its categories from the category sets. (A category cannot be
    ///    excepted from `.all`, so an Always open *category* does not reach a
    ///    Keep only frost — only its apps do.)
    /// 3. A running source adds what it covers, to the Deep store if it is
    ///    Deep and to the main one if not. Freeze these adds its apps, its
    ///    categories (for apps and for websites) and its web domains. Keep only
    ///    becomes `.all(except: kept apps)`; with two Keep only sources in one
    ///    store, an app stays open only if both keep it. Categories in a Keep
    ///    only pick cannot be honoured — iOS only excepts apps — so Keep only
    ///    is about the apps it lists. Websites are not shielded by Keep only:
    ///    Safari is an app like any other and freezes with the rest.
    /// 4. A Deep source ignores thaws: nothing a thaw names is subtracted from
    ///    the Deep store or excepted in it, so a thawed app under a Deep
    ///    *category* that started during the thaw is frozen again.
    /// 5. Otherwise a thaw takes its target out of the main store: `*` drops
    ///    the source entirely, a token id takes that app / category / site out
    ///    of it, and a thawed app is excepted from its category policy. A
    ///    *category* thaw under a running Keep only source drops that source
    ///    while the thaw lasts, since `.all` cannot except a category; the
    ///    shield usually hands over the app itself, so this only happens when
    ///    it could not.
    static func shieldPlan(
        _ p: FreezePolicy,
        at t: Date,
        selection: (String?) -> FamilyActivitySelection?,
        resolve: (String) -> FreezeTarget?
    ) -> FreezeShieldPlan {
        var plan = FreezeShieldPlan()
        let never = selection(p.groups.neverOpen.iosSelection) ?? FamilyActivitySelection()
        let always = selection(p.groups.alwaysOpen.iosSelection) ?? FamilyActivitySelection()
        let thaw = thawed(p, at: t, resolve: resolve)

        plan.never.add(apps: never.applicationTokens, categories: never.categoryTokens, webDomains: never.webDomainTokens)
        plan.adultFilter = p.groups.adultSites

        for source in active(p, t) {
            if !source.deep && thaw.all { continue }
            let picked = selection(source.apps.iosSelection)
            if source.apps.keepOnly {
                // No saved pick keeps nothing, so it covers everything — the
                // same as Dart's keep-only over an empty list.
                let kept = picked?.applicationTokens ?? []
                if source.deep {
                    plan.deep.keep(kept)
                } else {
                    if !thaw.categories.isEmpty { continue }
                    plan.main.keep(kept.union(thaw.apps))
                }
                continue
            }
            guard let picked else { continue }
            var apps = picked.applicationTokens.subtracting(always.applicationTokens)
            var categories = picked.categoryTokens.subtracting(always.categoryTokens)
            var webDomains = picked.webDomainTokens.subtracting(always.webDomainTokens)
            if source.deep {
                plan.deep.add(apps: apps, categories: categories, webDomains: webDomains)
            } else {
                apps.subtract(thaw.apps)
                categories.subtract(thaw.categories)
                webDomains.subtract(thaw.webDomains)
                plan.main.add(apps: apps, categories: categories, webDomains: webDomains)
            }
        }
        plan.deep.categoryExcept = always.applicationTokens
        plan.deep.webCategoryExcept = always.webDomainTokens
        plan.main.categoryExcept = always.applicationTokens.union(thaw.apps)
        plan.main.webCategoryExcept = always.webDomainTokens.union(thaw.webDomains)
        if let kept = plan.deep.allCategoriesExcept {
            plan.deep.allCategoriesExcept = kept.union(always.applicationTokens)
        }
        if let kept = plan.main.allCategoriesExcept {
            plan.main.allCategoriesExcept = kept.union(always.applicationTokens)
        }
        return plan
    }

    /// What the shield over one app (or site) should say: whether it is in
    /// Never open, whether a Deep freeze covers it, and when it next opens.
    /// `app` / `category` / `webDomain` are whatever the system handed the
    /// shield; a category-shielded app comes with both.
    static func describe(
        _ p: FreezePolicy,
        at t: Date,
        app: ApplicationToken?,
        category: ActivityCategoryToken?,
        webDomain: WebDomainToken?,
        selection: (String?) -> FamilyActivitySelection?
    ) -> FreezeShieldInfo {
        var info = FreezeShieldInfo()
        info.breath = breath(p, at: t)
        if listed(selection(p.groups.neverOpen.iosSelection), app: app, category: category, webDomain: webDomain) {
            info.never = true
            return info
        }
        var ends: [Date] = []
        var deepEnds: [Date] = []
        var endless = false
        var deepEndless = false
        for source in active(p, t) {
            let picked = selection(source.apps.iosSelection)
            let covering: Bool
            if source.apps.keepOnly {
                // As in `shieldPlan`: Keep only is about apps, and by app token.
                let kept = app.map { picked?.applicationTokens.contains($0) ?? false } ?? false
                covering = webDomain == nil && !kept
            } else {
                covering = listed(picked, app: app, category: category, webDomain: webDomain)
            }
            guard covering else { continue }
            info.covered = true
            if let end = source.end { ends.append(end) } else { endless = true }
            if source.deep {
                info.deep = true
                if let end = source.end { deepEnds.append(end) } else { deepEndless = true }
            }
        }
        // When the app really opens again (§4): with two freezes on it, it
        // stays frozen until the *last* one ends — and if any of them has no
        // end, that is "Until you stop". A thaw does not enter into it: the
        // shield only shows while the app is frozen. The Deep freeze line is
        // the same rule over the Deep sources alone.
        info.until = endless ? nil : ends.max()
        info.deepUntil = deepEndless ? nil : deepEnds.max()
        return info
    }

    private static func listed(
        _ picked: FamilyActivitySelection?,
        app: ApplicationToken?,
        category: ActivityCategoryToken?,
        webDomain: WebDomainToken?
    ) -> Bool {
        guard let picked else { return false }
        if let app, picked.applicationTokens.contains(app) { return true }
        if let category, picked.categoryTokens.contains(category) { return true }
        if let webDomain, picked.webDomainTokens.contains(webDomain) { return true }
        return false
    }
}

// MARK: - Local time

/// Local wall-clock arithmetic, matching Dart's `DateTime` constructors.
///
/// Gregorian on purpose, whatever calendar the phone is set to: `from_day` and
/// `until_day` are Gregorian dates, and weekdays must mean the same thing on
/// both sides of the channel.
enum FreezeTime {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }

    static func date(ms: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
    }

    static func ms(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// Local midnight at the start of `t`'s day.
    static func dayStart(_ t: Date) -> Date {
        calendar.startOfDay(for: t)
    }

    /// The start of the day `n` days after `day`'s.
    static func addDays(_ day: Date, _ n: Int) -> Date {
        let cal = calendar
        let start = cal.startOfDay(for: day)
        return cal.date(byAdding: .day, value: n, to: start) ?? start.addingTimeInterval(TimeInterval(n) * 86_400)
    }

    /// Dart's `DateTime(y, m, d, 0, minute)`: the wall-clock time `minute`
    /// minutes into `day`, rolling into the next day past 1440 (and the
    /// previous one below 0).
    static func at(_ day: Date, _ minute: Int) -> Date {
        let cal = calendar
        let extra = minute >= 0 ? minute / 1440 : -((1439 - minute) / 1440)
        let m = minute - extra * 1440
        let base = addDays(day, extra)
        var c = cal.dateComponents([.year, .month, .day], from: base)
        c.hour = m / 60
        c.minute = m % 60
        c.second = 0
        return cal.date(from: c) ?? base.addingTimeInterval(TimeInterval(m) * 60)
    }

    static func minuteOfDay(_ t: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: t)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// 1 = Monday … 7 = Sunday, like Dart's `DateTime.weekday`.
    static func isoWeekday(_ t: Date) -> Int {
        let w = calendar.component(.weekday, from: t) // 1 = Sunday … 7 = Saturday
        return (w + 5) % 7 + 1
    }

    /// `yyyyMMdd` as an integer, for comparing whole days.
    static func dayKey(_ t: Date) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: t)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// The key of a `yyyy-MM-dd` string, or nil if it is not one. Out-of-range
    /// days roll over the way Dart's `DateTime(y, m, d)` does.
    static func dayKey(parsing s: String) -> Int? {
        let parts = s.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: y, month: m, day: d))
        else { return nil }
        return dayKey(date)
    }

    /// `yyyy-MM-dd`.
    static func dayString(_ t: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: t)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "3:42" — h:mm, no AM/PM.
    static func bareClock(_ t: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: t)
        let h = c.hour ?? 0
        return String(format: "%ld:%02ld", h % 12 == 0 ? 12 : h % 12, c.minute ?? 0)
    }

    /// "1:00 PM".
    static func clock(_ t: Date) -> String {
        let h = calendar.component(.hour, from: t)
        return bareClock(t) + (h < 12 ? " AM" : " PM")
    }
}
