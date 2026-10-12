import SwiftUI

/// Aqademiq on the wrist.
///
/// One screen and one job: the running session, and the two presses that
/// change it. §7 puts the watch alongside the Control Centre control and the
/// Action Button — all four are the same intent wearing different clothes, and
/// the wrist's version of "freeze, don't quit" is the one you can reach without
/// finding the phone at all.
///
/// Everything the app can do lives on the phone. This target owns no session
/// logic, no timer that could disagree with the phone's, and no network. It
/// draws the last state it was handed and sends presses back.
@main
struct AqademiqWatchApp: App {
    @StateObject private var link = WatchLink()

    var body: some Scene {
        WindowGroup {
            WatchSessionView(link: link)
        }
    }
}
