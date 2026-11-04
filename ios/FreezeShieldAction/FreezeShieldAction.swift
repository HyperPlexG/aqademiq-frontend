import Foundation
import ManagedSettings

/// The frozen screen's two buttons (APP_FREEZE.md §4, §1.2).
///
///  * **Back to focus** closes the frozen app (`.close` — iOS's own way home).
///  * **Thaw · Ns** cannot thaw here: the breath and the thaw length are
///    Aqademiq's, and a ShieldAction extension cannot open an app. So it queues
///    a `thaw_request` naming the app, posts "Thaw in Aqademiq" — whose tap
///    opens the app, which picks the request up — and closes the frozen app.
///
/// `.close` rather than `.defer` for Thaw: `.defer` keeps the shield up and
/// asks FreezeShield to draw it again, which would count as another cover and
/// step the copy on to "Still on ice." for a press that was the student doing
/// exactly what was offered. Closed, they land on the home screen with the
/// banner on top, one tap from the breath.
final class FreezeShieldActionDelegate: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, target: FreezeStore.tokenId(application, kind: FreezeStore.appKind), completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, target: FreezeStore.tokenId(webDomain, kind: FreezeStore.webKind), completionHandler)
    }

    /// An app shielded by its category arrives here with only the category's
    /// token. FreezeShield noted which app it drew that shield for, so the
    /// thaw names the app; only if that note is missing does it fall back to
    /// the category, which thaws the whole category for the thaw's length.
    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let categoryId = FreezeStore.tokenId(category, kind: FreezeStore.categoryKind)
        let target = categoryId.flatMap { FreezeStore.lastShieldedApp(inCategory: $0) } ?? categoryId
        respond(to: action, target: target, completionHandler)
    }

    private func respond(
        to action: ShieldAction,
        target: String?,
        _ completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            if let target {
                FreezeStore.queueEvent(type: FreezeStore.thawRequest, target: target)
            }
            // Close only once the banner is handed over: the extension can be
            // torn down as soon as it answers.
            FreezeNotify.thawReady { completionHandler(.close) }
        @unknown default:
            completionHandler(.close)
        }
    }
}
