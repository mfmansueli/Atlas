//
//  PageActionDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 80's page action at the top (`-AtlasDebugScene <id>`): the
/// toolbar's one create button for the section, where the Autopilot button
/// was, and the page without its own.
///
/// - `bar-pages`: Custom Product Pages' list, New Page….
/// - `bar-events`: In-App Events' gallery, New Event….
/// - `bar-pricing`: Pricing's products, Add Subscription….
/// - `bar-ft`: Nominations' gallery, New Nomination….
/// - `bar-shots`: Screenshots' language page in English (U.S.), Add
///   Screenshots…, the drop-files tile still in the row.
enum PageActionDebugScenes {
    static let ids = ["bar-pages", "bar-events", "bar-pricing", "bar-ft", "bar-shots"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "bar-pages": ProductPagesDebugScenes.view(for: "cp")
        case "bar-events": InAppEventsDebugScenes.view(for: "ev")
        case "bar-pricing": PricingDebugScenes.scene()
        case "bar-ft": NominationsDebugScenes.view(for: "ft-gallery")
        case "bar-shots": screenshots()
        default: nil
        }
    }

    /// Lumen Journal's English (U.S.) page on iPhone.
    @MainActor
    private static func screenshots() -> AnyView {
        let center = ScreenshotsDocumentCenter.shared
        center.diskStore = nil
        let screenshots = DebugScreenshotsServices(opening: ScreenshotsDebugOpening { model in
            model.pageLocale = StoreLocaleCatalog.locale(code: "en-US")
            model.displayType = .iPhone
        }, documentCenter: center)
        screenshots.opensLanguagePage = true
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return AnyView(DebugMainScene(services: services, section: .screenshots, pendingChanges: DebugWorkspace.pendingChanges))
    }
}
#endif
