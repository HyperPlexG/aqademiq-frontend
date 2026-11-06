import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The frozen screen (APP_FREEZE.md §4): what Screen Time draws over an app
/// App freeze is holding.
///
/// iOS asks this extension for the copy each time it shows the shield. The
/// copy steps by how often the shield has covered *that app* this thaw day
/// (from 4 AM), capped at three — counted here, since this is the only code
/// that knows the shield appeared (asks for the same app within 5 seconds
/// are one appearance):
///
///   1  Ada's sitting on this one.   Yours again at 3:42
///   2  Still on ice.                3:42
///   3  Frozen.                      3:42
///
/// The time is when the app really unfreezes: the latest end among the freezes
/// covering it, or "Until you stop" if any of them has no end. Never open says
/// so and offers no thaw; a Deep freeze offers no thaw either and says until
/// when instead.
///
/// The design's ground is a lavender gradient, which a ShieldConfiguration
/// cannot draw; its middle stop is used as a flat colour.
final class FreezeShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shield(app: application.token, category: nil, webDomain: nil)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // ShieldAction will be handed only the category; leave it the app.
        if let app = application.token, let token = category.token {
            FreezeStore.noteShield(app: app, category: token)
        }
        return shield(app: application.token, category: category.token, webDomain: nil)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(app: nil, category: nil, webDomain: webDomain.token)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        shield(app: nil, category: category.token, webDomain: webDomain.token)
    }

    // MARK: - Copy

    private func shield(
        app: ApplicationToken?,
        category: ActivityCategoryToken?,
        webDomain: WebDomainToken?
    ) -> ShieldConfiguration {
        let now = Date()
        var info = FreezeShieldInfo()
        if let policy = FreezeStore.loadPolicy() {
            info = FreezeRules.describe(
                policy,
                at: now,
                app: app,
                category: category,
                webDomain: webDomain,
                selection: FreezeSelections().get
            )
        }

        // Counted per app where there is one, so two apps in one category step
        // separately — and once per appearance: iOS may ask for the same
        // shield again within moments (`countShield`).
        //
        // Every count is a write to the App Group from this extension. That
        // it sticks has to be seen on a device (APP_FREEZE.md §7); if it does
        // not, the copy simply stays at stage 1.
        var countId = "unknown"
        if let app, let id = FreezeStore.tokenId(app, kind: FreezeStore.appKind) {
            countId = id
        } else if let webDomain, let id = FreezeStore.tokenId(webDomain, kind: FreezeStore.webKind) {
            countId = id
        } else if let category, let id = FreezeStore.tokenId(category, kind: FreezeStore.categoryKind) {
            countId = id
        }
        let stage = min(max(FreezeStore.countShield(countId, at: now), 1), 3)

        let title: String
        var line: String?
        var thaw: String?
        if info.never {
            title = "Never open."
            line = "This one stays frozen."
        } else {
            title = ["Ada's sitting on this one.", "Still on ice.", "Frozen."][stage - 1]
            if info.deep {
                line = info.deepUntil.map { "Deep freeze until \(FreezeTime.clock($0))" } ?? "Deep freeze until you stop"
            } else {
                if info.covered {
                    if let until = info.until {
                        let at = FreezeTime.bareClock(until)
                        line = stage == 1 ? "Yours again at \(at)" : at
                    } else {
                        line = "Until you stop"
                    }
                }
                // Offered even when nothing seems to cover it: then the shield
                // is stale, and opening Aqademiq re-applies the policy.
                thaw = "Thaw · \(info.breath)s"
            }
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: Palette.ground,
            icon: Palette.glyph,
            title: ShieldConfiguration.Label(text: title, color: Palette.ink),
            subtitle: line.map { ShieldConfiguration.Label(text: $0, color: Palette.line) },
            primaryButtonLabel: ShieldConfiguration.Label(text: "Back to focus", color: .white),
            primaryButtonBackgroundColor: Palette.primary,
            secondaryButtonLabel: thaw.map { ShieldConfiguration.Label(text: $0, color: Palette.ink) }
        )
    }
}

/// §4's colours.
private enum Palette {
    /// `#EBE5FC`, the middle of the `#F8F6FF → #EBE5FC → #DDD4F8` ground.
    static let ground = rgb(0xEBE5FC)
    static let ink = rgb(0x1A1320)
    static let line = rgb(0x584F70)
    static let primary = rgb(0x111111)
    /// The thaw glyph's `#6B5CF0`, as the shield's icon.
    static let glyph = UIImage(
        systemName: "snowflake",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
    )?.withTintColor(rgb(0x6B5CF0), renderingMode: .alwaysOriginal)

    static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
