import Foundation

// App freeze — the policy Dart hands over in `applyPolicy`, as the native side
// reads it (APP_FREEZE.md §3).
//
// Compiled into Runner and into all three freeze extensions, so a frost reads
// the same whether Aqademiq is open or not. It mirrors `freeze_models.dart`
// field for field, with the same tolerance: a missing key falls back to the
// Dart default, a key of the wrong type counts as missing, unknown keys are
// ignored (the policy is forward-compatible), and one frost or grant that
// cannot be read is dropped rather than failing the whole policy — one bad
// entry must not stop every other frost.
//
// Times stay exactly as they travel, milliseconds since the epoch, so encoding
// a policy gives back the JSON it came from; `Date` accessors sit beside them.
// Plain Foundation: nothing in here needs Screen Time, so it builds on the
// app's iOS 13 floor without availability checks.

/// A set of apps. On iOS its identity is `iosSelection`, the App Group key of a
/// saved `FamilyActivitySelection`; `packages` is Android's and unused here.
struct FreezeAppSet: Codable, Equatable {
    static let keepOnlyMode = "keepOnly"
    static let freezeTheseMode = "freezeThese"
    static let empty = FreezeAppSet()

    var packages: [String]
    var iosSelection: String?
    var iosCount: Int
    /// `freezeThese` or `keepOnly`. Keep only freezes everything it does not list.
    var mode: String

    var keepOnly: Bool { mode == FreezeAppSet.keepOnlyMode }

    enum CodingKeys: String, CodingKey {
        case packages
        case iosSelection = "ios_selection"
        case iosCount = "ios_count"
        case mode
    }

    init(packages: [String] = [], iosSelection: String? = nil, iosCount: Int = 0, mode: String = FreezeAppSet.freezeTheseMode) {
        self.packages = packages
        self.iosSelection = iosSelection
        self.iosCount = iosCount
        self.mode = mode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        packages = c.fzStrings(.packages)
        iosSelection = c.fz(String.self, .iosSelection)
        iosCount = c.fzInt(.iosCount).map { Int(clamping: $0) } ?? 0
        mode = c.fz(String.self, .mode) == FreezeAppSet.keepOnlyMode ? FreezeAppSet.keepOnlyMode : FreezeAppSet.freezeTheseMode
    }
}

/// A frost: a rule that freezes a set of apps, by schedule or as a session.
struct FreezeFrost: Codable, Equatable {
    var id: String
    var name: String
    /// `schedule` or `session`.
    var kind: String
    /// ISO weekdays, 1 = Monday … 7 = Sunday.
    var days: [Int]
    /// Minutes after local midnight, 0…1440. `end <= start` runs overnight;
    /// 0 → 1440 is all day.
    var start: Int
    var end: Int
    /// Optional date range, `yyyy-MM-dd`, both ends inclusive.
    var fromDay: String?
    var untilDay: String?
    /// Session frosts: how long one run lasts; nil runs until stopped.
    var sessionMinutes: Int?
    var sessionStartedAt: Int64?
    var deep: Bool
    var enabled: Bool
    /// "End early": off until this moment.
    var skipUntil: Int64?
    var apps: FreezeAppSet

    enum CodingKeys: String, CodingKey {
        case id, name, kind, days, start, end
        case fromDay = "from_day"
        case untilDay = "until_day"
        case sessionMinutes = "session_minutes"
        case sessionStartedAt = "session_started_at"
        case deep, enabled
        case skipUntil = "skip_until"
        case apps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.fz(String.self, .id), let name = c.fz(String.self, .name) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "A frost needs an id and a name")
            )
        }
        self.id = id
        self.name = name
        kind = c.fz(String.self, .kind) == "session" ? "session" : "schedule"
        // Dart: `_ints(days).where(1…7).toSet()` — and no default: absent is no days.
        days = Array(Set(c.fzInts(.days).filter { (1...7).contains($0) })).sorted()
        start = min(max(c.fzInt(.start).map { Int(clamping: $0) } ?? 540, 0), 1440)
        end = min(max(c.fzInt(.end).map { Int(clamping: $0) } ?? 780, 0), 1440)
        // A date that does not parse is no date at all, as in Dart's `_parseDay`.
        let from = c.fz(String.self, .fromDay)
        fromDay = from.flatMap(FreezeTime.dayKey(parsing:)) == nil ? nil : from
        let until = c.fz(String.self, .untilDay)
        untilDay = until.flatMap(FreezeTime.dayKey(parsing:)) == nil ? nil : until
        sessionMinutes = c.fzInt(.sessionMinutes).map { Int(clamping: $0) }
        sessionStartedAt = c.fzInt(.sessionStartedAt)
        deep = c.fz(Bool.self, .deep) == true
        enabled = c.fz(Bool.self, .enabled) != false
        skipUntil = c.fzInt(.skipUntil)
        apps = c.fz(FreezeAppSet.self, .apps) ?? .empty
    }

    var isSession: Bool { kind == "session" }
    var allDay: Bool { start == 0 && end >= 1440 }
    var overnight: Bool { !allDay && end <= start }

    var sessionStart: Date? { sessionStartedAt.map(FreezeTime.date(ms:)) }
    var skipUntilDate: Date? { skipUntil.map(FreezeTime.date(ms:)) }
    /// `yyyyMMdd` as an integer, for ordering whole days.
    var fromKey: Int? { fromDay.flatMap(FreezeTime.dayKey(parsing:)) }
    var untilKey: Int? { untilDay.flatMap(FreezeTime.dayKey(parsing:)) }
}

/// "Freeze now": an ad-hoc freeze that is not a frost.
struct FreezeNowPolicy: Codable, Equatable {
    var startedAt: Int64
    /// Nil = "Until I stop".
    var endsAt: Int64?
    var deep: Bool
    var apps: FreezeAppSet
    var withFocus: Bool

    enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case endsAt = "ends_at"
        case deep, apps
        case withFocus = "with_focus"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let started = c.fzInt(.startedAt) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Freeze now needs started_at")
            )
        }
        startedAt = started
        endsAt = c.fzInt(.endsAt)
        deep = c.fz(Bool.self, .deep) == true
        apps = c.fz(FreezeAppSet.self, .apps) ?? .empty
        withFocus = c.fz(Bool.self, .withFocus) == true
    }

    var startedAtDate: Date { FreezeTime.date(ms: startedAt) }
    var endsAtDate: Date? { endsAt.map(FreezeTime.date(ms:)) }
}

/// A thaw: `target` opens until `until`. `target` is `*` (everything a Deep
/// freeze is not holding) or, on iOS, the id `FreezeStore.tokenId` gave the
/// app the shield covered.
struct FreezeGrant: Codable, Equatable {
    var target: String
    var until: Int64
    var startedAt: Int64
    var label: String?

    enum CodingKeys: String, CodingKey {
        case target, until
        case startedAt = "started_at"
        case label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let target = c.fz(String.self, .target), let until = c.fzInt(.until) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "A grant needs a target and an end")
            )
        }
        self.target = target
        self.until = until
        startedAt = c.fzInt(.startedAt) ?? until
        label = c.fz(String.self, .label)
    }

    var untilDate: Date { FreezeTime.date(ms: until) }
}

/// "Thaw everything": every frost stands down until `until` (nil = until
/// brought back), except what `holds` keeps — a Deep freeze that was already
/// running, until the end of its window.
struct FreezeStanddown: Codable, Equatable {
    var since: Int64
    var until: Int64?
    var holds: [String: Int64]

    enum CodingKeys: String, CodingKey {
        case since, until, holds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let since = c.fzInt(.since) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "A stand-down needs since")
            )
        }
        self.since = since
        until = c.fzInt(.until)
        holds = (c.fz([String: FzNumber].self, .holds) ?? [:]).compactMapValues { $0.value }
    }

    var sinceDate: Date { FreezeTime.date(ms: since) }
    var untilDate: Date? { until.map(FreezeTime.date(ms:)) }
    var holdDates: [String: Date] { holds.mapValues(FreezeTime.date(ms:)) }
}

/// Always open (never frozen), Never open (always frozen) and Distracting
/// (never frozen by the group; Ada checks in).
struct FreezeGroupsPolicy: Codable, Equatable {
    var alwaysOpen: FreezeAppSet
    var neverOpen: FreezeAppSet
    var distracting: FreezeAppSet
    /// Never open → "Adult sites": the system web content filter.
    var adultSites: Bool

    enum CodingKeys: String, CodingKey {
        case alwaysOpen = "always_open"
        case neverOpen = "never_open"
        case distracting
        case adultSites = "adult_sites"
    }

    init() {
        alwaysOpen = .empty
        neverOpen = .empty
        distracting = .empty
        adultSites = false
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        alwaysOpen = c.fz(FreezeAppSet.self, .alwaysOpen) ?? .empty
        neverOpen = c.fz(FreezeAppSet.self, .neverOpen) ?? .empty
        distracting = c.fz(FreezeAppSet.self, .distracting) ?? .empty
        adultSites = c.fz(Bool.self, .adultSites) == true
    }
}

struct FreezeThawSettings: Codable, Equatable {
    static let lengths = [2, 5, 10, 15]

    /// `standard` or `increasing`.
    var resistance: String
    var minutes: Int

    var increasing: Bool { resistance == "increasing" }

    enum CodingKeys: String, CodingKey {
        case resistance, minutes
    }

    init() {
        resistance = "standard"
        minutes = 2
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resistance = c.fz(String.self, .resistance) == "increasing" ? "increasing" : "standard"
        let m = c.fzInt(.minutes).map { Int(clamping: $0) } ?? 2
        minutes = FreezeThawSettings.lengths.contains(m) ? m : 2
    }
}

/// Everything App freeze keeps, in one object — minus the thaw history, plus
/// `generated_at`, `thaws_today`, `thaws_counted_at` and `focus_label`.
struct FreezePolicy: Codable, Equatable {
    var v: Int
    var generatedAt: Int64?
    var setUp: Bool
    var frosts: [FreezeFrost]
    var groups: FreezeGroupsPolicy
    var thaw: FreezeThawSettings
    var now: FreezeNowPolicy?
    var grants: [FreezeGrant]
    var standdown: FreezeStanddown?
    var recentApps: FreezeAppSet
    /// Thaws taken in the thaw day that contains `thawsCountedAt`.
    var thawsToday: Int
    var thawsCountedAt: Int64?
    var focusLabel: String?

    enum CodingKeys: String, CodingKey {
        case v
        case generatedAt = "generated_at"
        case setUp = "set_up"
        case frosts, groups, thaw, now, grants, standdown
        case recentApps = "recent_apps"
        case thawsToday = "thaws_today"
        case thawsCountedAt = "thaws_counted_at"
        case focusLabel = "focus_label"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = c.fzInt(.v).map { Int(clamping: $0) } ?? 1
        generatedAt = c.fzInt(.generatedAt)
        setUp = c.fz(Bool.self, .setUp) == true
        frosts = c.fzList(FreezeFrost.self, .frosts)
        groups = c.fz(FreezeGroupsPolicy.self, .groups) ?? FreezeGroupsPolicy()
        thaw = c.fz(FreezeThawSettings.self, .thaw) ?? FreezeThawSettings()
        now = c.fz(FreezeNowPolicy.self, .now)
        grants = c.fzList(FreezeGrant.self, .grants)
        standdown = c.fz(FreezeStanddown.self, .standdown)
        recentApps = c.fz(FreezeAppSet.self, .recentApps) ?? .empty
        thawsToday = c.fzInt(.thawsToday).map { Int(clamping: $0) } ?? 0
        thawsCountedAt = c.fzInt(.thawsCountedAt)
        focusLabel = c.fz(String.self, .focusLabel)
    }

    var thawsCountedAtDate: Date? { thawsCountedAt.map(FreezeTime.date(ms:)) }

    /// Nil when `json` is not a JSON object at all; anything inside it that
    /// cannot be read falls back to its default.
    static func decode(_ json: String) -> FreezePolicy? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FreezePolicy.self, from: data)
    }
}

// MARK: - Lenient reading

/// Each reader returns nil for a key that is absent, null or of the wrong type,
/// and never throws — the Swift spelling of the `is int ? … : null` checks in
/// `freeze_models.dart`.
extension KeyedDecodingContainer {
    func fz<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        try? decodeIfPresent(type, forKey: key)
    }

    /// An integer, accepting a JSON number written with a fraction (truncated,
    /// like Dart's `num.toInt()`).
    func fzInt(_ key: Key) -> Int64? {
        fz(FzNumber.self, key)?.value
    }

    /// The integers in a list, skipping anything that is not one.
    func fzInts(_ key: Key) -> [Int] {
        (fz([FzNumber].self, key) ?? []).compactMap { $0.value.map { Int(clamping: $0) } }
    }

    /// The strings in a list, skipping anything that is not one.
    func fzStrings(_ key: Key) -> [String] {
        (fz([FzLossy<String>].self, key) ?? []).compactMap { $0.value }
    }

    /// The readable items of a list; the rest are dropped.
    func fzList<T: Decodable>(_ type: T.Type, _ key: Key) -> [T] {
        (fz([FzLossy<T>].self, key) ?? []).compactMap { $0.value }
    }
}

/// A JSON number as an integer, or nil — never a decoding failure.
struct FzNumber: Decodable {
    let value: Int64?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int64.self) {
            value = i
        } else if let d = try? c.decode(Double.self), d.isFinite {
            value = Int64(exactly: d.rounded(.towardZero))
        } else {
            value = nil
        }
    }
}

/// One list item that may or may not decode.
struct FzLossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
