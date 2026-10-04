import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// The one activity Aqademiq is allowed to run.
///
/// The Dynamic Island is scarce, shared and system-owned, and students judge
/// apps harshly for squatting in it. This is taken for an active focus session
/// and nothing else — never a due task, never an Ada reply, never a streak.
/// When no session is running we are not there at all.
@available(iOS 16.1, *)
struct FocusActivityAttributes: ActivityAttributes {
    /// The part that changes during the session.
    ///
    /// Everything here is cheap on purpose. The countdown is rendered by the
    /// system from `endsAt`, so the only thing an update ever really carries is
    /// Ada's stage — five of those across a whole session, one of them the
    /// start. A per-second update is both impossible and unnecessary.
    public struct ContentState: Codable, Hashable {
        /// When the session finishes. Freezing pushes this forward.
        var endsAt: Date

        /// Held. Swaps the live timer for static text, because a system
        /// countdown cannot be paused.
        var frozen: Bool

        /// `0..4`.
        var meltStage: Int

        /// Only read while `frozen`, where the live clock cannot be used.
        var remainingSec: Int

        /// Total planned length, so the ring can show what has been spent.
        var durationSec: Int

        /// Which soundscape is sounding. Shown, never offered — the modes
        /// cross-fade over five adaptive seconds and cannot be driven from a
        /// lock-screen tap without sounding broken.
        var prismMode: String?

        var spent: Double {
            guard durationSec > 0 else { return 0 }
            return min(max(Double(durationSec - remainingSec) / Double(durationSec), 0), 1)
        }
    }

    /// Fixed for the life of the session: what the student sat down to do.
    ///
    /// A student who long-presses at minute forty has usually forgotten what
    /// they sat down for, and this is where that gets answered.
    var taskTitle: String
    var subjectLabel: String?
    var subjectTint: String?
}
#endif
