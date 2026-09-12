import Foundation
import WatchConnectivity

/// The phone's half of the wrist.
///
/// Named apart from the watch target's own `WatchLink` deliberately: they are
/// separate modules and the compiler would not mind sharing a name, but the two
/// ends of one link reading identically in a stack trace helps nobody.
///
/// Everywhere else the ambient surfaces read one shared object out of an App
/// Group. The watch cannot: it is a separate device with its own container, and
/// no amount of entitlement sharing bridges that. So this is the one surface
/// that needs an actual transport, and WatchConnectivity is it.
///
/// Two directions, two primitives, chosen for what they guarantee:
///
///   * **Down** (`updateApplicationContext`) — the newest state replaces any
///     older one still queued, and the system delivers it whether or not the
///     watch app is running. That coalescing is exactly the budget the rest of
///     the design keeps: a melt stage or a freeze is worth sending, a second
///     passing is not, and if three states pile up while the watch is asleep
///     the stale two are worthless anyway.
///
///   * **Up** (`sendMessage`, falling back to `transferUserInfo`) — a press has
///     to arrive once and must not be coalesced away, because two freezes are
///     not one freeze. sendMessage can wake this app in the background;
///     transferUserInfo queues it durably when the phone is unreachable.
///
/// It is deliberately dumb about content. The payload is the same flat
/// dictionary already written to the App Group, so there is no second schema to
/// keep in step — the watch reads the fields it can draw and ignores the rest.
final class WatchBridge: NSObject {
    /// Called with `freeze`, `resume`, `end` or `start5` when the wrist asks
    /// for something. Routed by the plugin into the same pending-action path a
    /// widget press takes, so there is one way into the session and not two.
    var onCommand: ((String) -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    /// Last thing we sent, so an unchanged state is not re-sent.
    ///
    /// `updateApplicationContext` throws if handed a payload identical to the
    /// outstanding one, and the ambient service already pushes on its own
    /// schedule — without this the log fills with failures that mean nothing.
    private var lastSent: NSDictionary?

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Mirror the shared state to the wrist.
    func push(_ state: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        let payload = state as NSDictionary
        guard payload != lastSent else { return }
        do {
            try session.updateApplicationContext(state)
            lastSent = payload
        } catch {
            // Not fatal and not worth retrying: the next state change pushes
            // again, and the watch redraws from whatever it last received.
            NSLog("[Aqademiq] watch context failed: \(error.localizedDescription)")
        }
    }
}

extension WatchBridge: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            NSLog("[Aqademiq] watch session failed: \(error.localizedDescription)")
        }
    }

    // Required on iOS. A watch being unpaired or swapped means the next one
    // starts from nothing, so drop the memo and let the next push through.
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        lastSent = nil
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        deliver(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        deliver(message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        deliver(userInfo)
    }

    private func deliver(_ payload: [String: Any]) {
        guard let action = payload["action"] as? String else { return }
        // Onto the main queue: this lands on a background thread, and the other
        // end of `onCommand` is a Flutter method channel.
        DispatchQueue.main.async { [weak self] in self?.onCommand?(action) }
    }
}
