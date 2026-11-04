import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// The wake-ups that keep App freeze running while Aqademiq is closed
/// (APP_FREEZE.md §5).
///
/// iOS runs no code of ours on a timer. What it will do is wake the
/// FreezeMonitor extension at the edges of DeviceActivity intervals, so every
/// moment the rules can change at gets an interval edge, and every edge just
/// re-evaluates the whole policy (`FreezeApply.applyNow`). The intervals carry
/// no meaning of their own — a frost's window opening is not "freeze these
/// apps", it is "look again now".
///
///  * `fz.frost.<id>` — one *daily* interval per schedule frost, its start and
///    end minute. iOS repeats it every day; the rules decide whether today is
///    one of its days and inside its dates.
///  * `fz.now`, `fz.standdown`, `fz.session.<id>`, `fz.grant.<n>` — one-off
///    intervals ending when Freeze now, the stand-down, a session frost or a
///    thaw ends. DeviceActivity refuses an interval under 15 minutes, so a short
///    one starts in the past: its start edge is then just a harmless re-apply,
///    and its end lands where it should.
///  * `fz.distracting` — a daily interval with one event, ten minutes of use of
///    the Distracting apps, which posts Ada's check-in.
///
/// Budget: iOS monitors at most 20 activities per app and refuses the 21st, so
/// this stays at `maxActivities` (18). One-offs come first, because they are
/// few and each guards a moment that would otherwise be missed: Freeze now and
/// the stand-down (one each), the three soonest session frosts and the three
/// soonest thaw ends. Then Distracting, then as many schedule frosts as are
/// left — running ones first, then by next start. Nothing is lost by the cut:
/// the monitor calls `reschedule` at every interval end, so the next soonest
/// thaw or frost is picked up as the earlier ones finish.
///
/// Rescheduling only restarts an activity whose schedule changed (a signature
/// per name in the App Group). That is what keeps it from looping: starting an
/// interval whose start is in the past fires `intervalDidStart` straight away,
/// and an unconditional restart from inside that callback would never stop.
@available(iOS 16.0, *)
enum FreezeSchedule {
    static let prefix = "fz."
    static let frostPrefix = "fz.frost."
    static let sessionPrefix = "fz.session."
    static let grantPrefix = "fz.grant."
    static let nowName = "fz.now"
    static let standdownName = "fz.standdown"
    static let distractingName = "fz.distracting"
    static let distractingEvent = "fz.distracting.10m"

    static let maxActivities = 18
    static let maxGrants = 3
    static let maxSessions = 3

    /// DeviceActivity's shortest interval.
    static let minimumInterval: TimeInterval = 15 * 60

    /// A callback this close before the edge it belongs to is treated as
    /// arriving on it (see `evaluationDate`).
    static let earlyTolerance: TimeInterval = 90

    static func owns(_ activity: DeviceActivityName) -> Bool {
        activity.rawValue.hasPrefix(prefix)
    }

    private struct Plan {
        let name: String
        let signature: String
        let schedule: DeviceActivitySchedule
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        /// When a one-off really ends, for `evaluationDate`.
        var boundary: Date?
    }

    /// Brings DeviceActivity in line with the stored policy: stops what is no
    /// longer wanted, starts what is new or changed, leaves the rest running.
    static func reschedule(now: Date = Date()) {
        let center = DeviceActivityCenter()
        let plans = FreezeStore.loadPolicy().map { desired($0, now: now) } ?? []
        let wanted = Set(plans.map { $0.name })

        let monitored = center.activities
        let stale = monitored.filter { owns($0) && !wanted.contains($0.rawValue) }
        // Never with an empty list: `stopMonitoring([])` stops everything.
        if !stale.isEmpty { center.stopMonitoring(stale) }

        let running = Set(monitored.map { $0.rawValue })
        var signatures = FreezeStore.scheduleSignatures().filter { wanted.contains($0.key) }
        var boundaries: [String: Int64] = [:]
        for plan in plans {
            if let boundary = plan.boundary { boundaries[plan.name] = FreezeTime.ms(boundary) }
            if signatures[plan.name] == plan.signature && running.contains(plan.name) { continue }
            // Written before starting: the start can call back into the monitor
            // at once, and it must already see this schedule as current.
            signatures[plan.name] = plan.signature
            FreezeStore.saveScheduleSignatures(signatures)
            do {
                try center.startMonitoring(DeviceActivityName(plan.name), during: plan.schedule, events: plan.events)
            } catch {
                signatures.removeValue(forKey: plan.name)
                NSLog("App freeze: could not schedule \(plan.name) — \(error)")
            }
        }
        FreezeStore.saveScheduleSignatures(signatures)
        FreezeStore.saveBoundaries(boundaries)
    }

    /// The moment a callback for `activity` should evaluate the rules at.
    ///
    /// Normally now. But a callback that arrives a little *before* its edge
    /// would evaluate a frost as still running and leave the shield up until
    /// the next edge, possibly hours away — so if the edge is at most
    /// `earlyTolerance` ahead, the rules are asked about the edge itself.
    static func evaluationDate(for activity: DeviceActivityName, ending: Bool, now: Date = Date()) -> Date {
        let name = activity.rawValue
        var edges: [Date] = []
        if name.hasPrefix(frostPrefix) {
            let id = String(name.dropFirst(frostPrefix.count))
            if let f = FreezeStore.loadPolicy()?.frosts.first(where: { $0.id == id }) {
                // The edge this callback is for: the scheduled end (23:59 for an
                // all-day frost, whose next day starts with its own callback).
                let minute = ending ? (f.allDay ? 1439 : f.end) : f.start
                let today = FreezeTime.dayStart(now)
                edges = [FreezeTime.at(today, minute), FreezeTime.at(today, minute + 1440)]
            }
        } else if ending, let ms = FreezeStore.boundaries()[name] {
            edges = [FreezeTime.date(ms: ms)]
        }
        let horizon = now.addingTimeInterval(earlyTolerance)
        if let edge = edges.first(where: { $0 > now && $0 <= horizon }) {
            return edge.addingTimeInterval(1)
        }
        return now
    }

    // MARK: - What to monitor

    private static func desired(_ p: FreezePolicy, now: Date) -> [Plan] {
        var out: [Plan] = []

        if let n = p.now, let end = n.endsAtDate,
           let plan = once(nowName, start: n.startedAtDate, end: end, now: now) {
            out.append(plan)
        }
        if let s = p.standdown, let until = s.untilDate,
           let plan = once(standdownName, start: s.sinceDate, end: until, now: now) {
            out.append(plan)
        }

        let sessions = p.frosts.compactMap { f -> (id: String, start: Date, end: Date)? in
            guard f.enabled, f.isSession, let start = f.sessionStart, let minutes = f.sessionMinutes else { return nil }
            let end = start.addingTimeInterval(TimeInterval(minutes) * 60)
            return end > now ? (id: f.id, start: start, end: end) : nil
        }.sorted { $0.end < $1.end }
        for s in sessions.prefix(maxSessions) {
            if let plan = once(sessionPrefix + s.id, start: s.start, end: s.end, now: now) { out.append(plan) }
        }

        // Thaws are named by slot, soonest end first; two thaws ending together
        // need only one wake-up.
        let grantEnds = Set(p.grants.map { $0.untilDate }.filter { $0 > now }).sorted()
        for (slot, end) in grantEnds.prefix(maxGrants).enumerated() {
            if let plan = once(grantPrefix + String(slot), start: nil, end: end, now: now) { out.append(plan) }
        }

        if let plan = distracting(p) { out.append(plan) }

        let room = max(maxActivities - out.count, 0)
        let frosts = p.frosts.compactMap { f -> (frost: FreezeFrost, next: Date)? in
            guard f.enabled, !f.isSession, !f.days.isEmpty else { return nil }
            if FreezeRules.windowAt(f, now) != nil { return (frost: f, next: now) }
            guard let next = FreezeRules.nextStart(f, now) else { return nil }
            return (frost: f, next: next)
        }.sorted { $0.next < $1.next }
        for entry in frosts.prefix(room) {
            out.append(daily(entry.frost))
        }
        return out
    }

    /// A one-off interval ending at `end` (and starting at `start`, if that is
    /// still ahead).
    private static func once(_ name: String, start: Date?, end: Date, now: Date) -> Plan? {
        // Whole minutes, rounded up, in case seconds are dropped: an edge a few
        // seconds late only re-applies; an edge a few seconds early would find
        // the thaw still running and leave it open until the next edge.
        let target = ceilMinute(end)
        guard target > now else { return nil }
        let cal = Calendar.current
        // DeviceActivity refuses an interval longer than about a week, so a far
        // end is reached in hops: each hop's end re-evaluates and reschedules.
        // Pinned to a day boundary so the hop — and so the signature — holds
        // still for the rest of today.
        let horizon = cal.startOfDay(for: now).addingTimeInterval(6 * 86_400)
        let finish = min(target, horizon)
        var begin = now
        var signature = "once:\(FreezeTime.ms(finish))"
        if let start, start > now {
            begin = ceilMinute(start)
            signature = "once:\(FreezeTime.ms(begin))-\(FreezeTime.ms(finish))"
        }
        if finish.timeIntervalSince(begin) < minimumInterval {
            // The < 15-minute trick: start it in the past.
            begin = finish.addingTimeInterval(-(minimumInterval + 60))
        }
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: begin),
            intervalEnd: cal.dateComponents(parts, from: finish),
            repeats: false
        )
        return Plan(name: name, signature: signature, schedule: schedule, boundary: finish)
    }

    /// A schedule frost's daily interval.
    private static func daily(_ f: FreezeFrost) -> Plan {
        let start = f.start % 1440
        var end: Int
        if f.allDay {
            // 0:00 – 23:59. The next day's 0:00 start re-evaluates, so the
            // minute in between is still covered.
            end = 1439
        } else {
            // 24:00 becomes 0:00, an interval that crosses midnight — like any
            // overnight frost.
            end = f.end % 1440
        }
        // A 24-hour overnight window (end == start): one minute short; the
        // next day's start callback covers the gap.
        if end == start { end = (start + 1439) % 1440 }
        // Shorter than DeviceActivity allows: stretch the interval to 15
        // minutes and put a warning where the window really ends, so
        // `intervalWillEndWarning` marks the edge.
        let length = (end - start + 1440) % 1440
        var warning: DateComponents?
        if length < 15 {
            warning = DateComponents(minute: 15 - length)
            end = (start + 15) % 1440
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: start / 60, minute: start % 60),
            intervalEnd: DateComponents(hour: end / 60, minute: end % 60),
            repeats: true,
            warningTime: warning
        )
        return Plan(
            name: frostPrefix + f.id,
            signature: "daily:\(start)-\(end)-\(warning?.minute ?? 0)",
            schedule: schedule
        )
    }

    /// Distracting: every day, an event at ten minutes of use of the group.
    private static func distracting(_ p: FreezePolicy) -> Plan? {
        let id = p.groups.distracting.iosSelection
        guard let picked = FreezeStore.selection(id), let data = FreezeStore.selectionData(id) else { return nil }
        if picked.applicationTokens.isEmpty && picked.categoryTokens.isEmpty && picked.webDomainTokens.isEmpty {
            return nil
        }
        let event = DeviceActivityEvent(
            applications: picked.applicationTokens,
            categories: picked.categoryTokens,
            webDomains: picked.webDomainTokens,
            threshold: DateComponents(minute: 10)
        )
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        return Plan(
            name: distractingName,
            signature: "distracting:\(FreezeStore.digest(data))",
            schedule: schedule,
            events: [DeviceActivityEvent.Name(distractingEvent): event]
        )
    }

    private static func ceilMinute(_ d: Date) -> Date {
        Date(timeIntervalSince1970: (d.timeIntervalSince1970 / 60).rounded(.up) * 60)
    }
}
