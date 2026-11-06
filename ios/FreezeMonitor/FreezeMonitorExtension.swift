import DeviceActivity
import Foundation

/// Runs App freeze while Aqademiq is closed (APP_FREEZE.md §5).
///
/// The app asks DeviceActivity for a handful of intervals (`FreezeSchedule`)
/// and iOS wakes this extension at their edges. Every edge does the same
/// thing: read the policy, evaluate the rules for this moment and rewrite the
/// shield's three ManagedSettingsStores (`FreezeApply`). A `fz.frost.<id>`
/// edge fires every day whether or not it is one of the frost's days;
/// `windowAt` is what checks the weekday and the dates, so an edge on an off
/// day simply finds nothing running.
///
/// Because no callback means anything by itself, a missed or doubled one costs
/// nothing — the next one sets the shield right. An activity without the `fz.`
/// prefix is not ours and is left alone.
final class FreezeMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard FreezeSchedule.owns(activity) else { return }
        FreezeApply.applyNow(date: FreezeSchedule.evaluationDate(for: activity, ending: false))
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard FreezeSchedule.owns(activity) else { return }
        FreezeApply.applyNow(date: FreezeSchedule.evaluationDate(for: activity, ending: true))
        // An interval ending is when the budget moves on: a finished thaw or
        // Freeze now is dropped, and the next soonest one is picked up. Only
        // here, never on a start — see FreezeSchedule on why that would loop.
        FreezeSchedule.reschedule()
    }

    /// Only a frost shorter than 15 minutes has a warning: its interval was
    /// stretched to the minimum, and the warning sits where the window ends.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        guard FreezeSchedule.owns(activity) else { return }
        FreezeApply.applyNow(date: FreezeSchedule.evaluationDate(for: activity, ending: true))
    }

    /// Ten minutes in a Distracting app today: Ada checks in, once.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity.rawValue == FreezeSchedule.distractingName else { return }
        // The extension can be suspended as soon as this returns, so wait
        // (briefly) for the notification to be handed over.
        let posted = DispatchSemaphore(value: 0)
        FreezeNotify.checkIn { posted.signal() }
        _ = posted.wait(timeout: .now() + 2)
    }
}
