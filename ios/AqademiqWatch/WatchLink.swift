import Foundation
import WatchConnectivity

/// One running session, as much of it as the wrist needs.
///
/// Deliberately not a copy of `AmbientState`: that type knows about the App
/// Group, the glanceable half and the week row, none of which reach the watch
/// or belong on it. This is the flat subset this screen can draw, decoded
/// leniently — a payload from a newer phone build carries fields this does not
/// know, and the right response to that is to ignore them, not to fail.
struct WatchSession: Equatable {
    var endsAt: Date
    var remainingSec: Int
    var frozen: Bool
    var meltStage: Int
    var durationSec: Int
    var taskTitle: String?
    var prismMode: String?

    /// How much of the session is gone: what Ada loses, the rail gains.
    var spent: Double {
        guard durationSec > 0 else { return 0 }
        return min(max(1 - Double(remainingSec) / Double(durationSec), 0), 1)
    }

    init?(_ raw: [String: Any]) {
        guard
            let iso = raw["endsAt"] as? String,
            let endsAt = WatchSession.formatter.date(from: iso)
        else { return nil }
        self.endsAt = endsAt
        remainingSec = raw["remainingSec"] as? Int ?? 0
        frozen = raw["frozen"] as? Bool ?? false
        meltStage = min(max(raw["meltStage"] as? Int ?? 0, 0), 4)
        durationSec = raw["durationSec"] as? Int ?? 0
        taskTitle = (raw["taskTitle"] as? String)?.nilIfBlank
        prismMode = (raw["prismMode"] as? String)?.nilIfBlank
    }

    /// The phone writes `toUtc().toIso8601String()`, which carries fractional
    /// seconds. ISO8601DateFormatter drops the string on the floor without
    /// this option, and a nil date here reads as "no session" — the failure
    /// mode is a watch that shows nothing during a session, which looks like a
    /// broken feature rather than a parsing bug.
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespaces).isEmpty ? nil : self }
}

/// The watch's half of the link. Receives state, sends presses.
///
/// `applicationContext` rather than messages for state: it survives the watch
/// app being asleep and always holds the newest value, which is what a surface
/// that is glanced at needs. Presses go the other way as messages, because a
/// press must arrive exactly once and must not be coalesced with the next one.
final class WatchLink: NSObject, ObservableObject {
    @Published private(set) var session: WatchSession?
    /// Set while a press is in flight, so the button can show it was heard.
    /// The phone owns the truth; this is only an acknowledgement, and it clears
    /// as soon as real state arrives.
    @Published private(set) var pending: String?

    private var wc: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    override init() {
        super.init()
        guard let wc else { return }
        wc.delegate = self
        wc.activate()
        // The context that arrived while this app was not running is already
        // waiting — read it rather than sitting empty until the next change.
        apply(wc.receivedApplicationContext)
    }

    func send(_ action: String) {
        guard let wc else { return }
        pending = action
        let payload = ["action": action]
        if wc.isReachable {
            wc.sendMessage(payload, replyHandler: { _ in }, errorHandler: { [weak self] _ in
                // Reachability can lapse between the check and the send.
                // Queue it durably rather than dropping the press.
                wc.transferUserInfo(payload)
                DispatchQueue.main.async { self?.pending = nil }
            })
        } else {
            wc.transferUserInfo(payload)
        }
        // Do not hold the spinner indefinitely: the phone answers by pushing
        // new state, and if it never does the button should be usable again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.pending = nil
        }
    }

    private func apply(_ context: [String: Any]) {
        let raw = context["session"] as? [String: Any]
        let next = raw.flatMap(WatchSession.init)
        DispatchQueue.main.async { [weak self] in
            self?.session = next
            self?.pending = nil
        }
    }
}

extension WatchLink: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        guard error == nil else { return }
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }
}
