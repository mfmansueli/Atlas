//
//  LoadingDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The loading states' DEBUG scenes (`-AtlasDebugScene <id>`): each
/// section or sheet while its data is still on its way from App Store
/// Connect, held there for a day so the skeleton can be looked at.
///
/// - `overview-loading`: Overview's cards; `shots-loading`: the
///   Screenshots section; `texts-loading`: Store Page's In-App Purchase
///   texts; `ev-loading`: In-App Events; `ft-loading`: Nominations;
///   `info-loading`: App Information; `priv-urls-loading`: App
///   Privacy's URLs.
/// - `rp-loading`: Review & Push checking the screenshots;
///   `submit-loading`: Submit for Review reading the builds;
///   `assets-loading`: the Asset Library; `paywall-loading`: the plans.
///
/// The others live with their sections: `lib-loading`, `store-loading`,
/// `cp-loading`, `a11y-loading`, `rv-loading`, `an-loading`,
/// `pricing-skeleton`.
enum LoadingDebugScenes {
    static let ids = [
        "overview-loading", "shots-loading", "texts-loading", "ev-loading", "ft-loading", "info-loading", "priv-urls-loading",
        "rp-loading", "submit-loading", "assets-loading", "paywall-loading",
    ]

    /// Long enough that nothing arrives while a scene is looked at.
    static let hold: Duration = .seconds(24 * 60 * 60)

    @MainActor
    static func view(for id: String) -> AnyView? {
        sectionScene(id) ?? sheetScene(id)
    }

    @MainActor
    private static func sectionScene(_ id: String) -> AnyView? {
        switch id {
        case "overview-loading":
            return main(section: .overview) { services in
                var storePage = DebugStorePageServices()
                storePage.summaryDelay = hold
                var pricing = DebugPricingServices()
                pricing.summaryDelay = hold
                var information = DebugAppInformationServices()
                information.summaryDelay = hold
                services.storePage = storePage
                services.pricing = pricing
                services.appInformation = information
            }
        case "shots-loading":
            return main(section: .screenshots) { $0.storePage = DebugStorePageServices(delay: hold) }
        case "texts-loading":
            var storePage = DebugStorePageServices()
            storePage.inAppTextsDelay = hold
            storePage.opening = DebugStorePageServices.Opening { $0.mode = .inAppTexts }
            return main(section: .storePage) { $0.storePage = storePage }
        case "ev-loading":
            var events = DebugInAppEventsServices()
            events.delay = hold
            return main(section: .inAppEvents, events: InAppEventsStore()) { $0.inAppEvents = events }
        case "ft-loading":
            var nominations = DebugNominationsServices()
            nominations.delay = hold
            return main(section: .nominations) { $0.nominations = nominations }
        case "info-loading":
            return main(section: .appInformation) { $0.appInformation = DebugAppInformationServices(delay: hold) }
        case "priv-urls-loading":
            var information = DebugAppInformationServices()
            information.privacyURLsDelay = hold
            information.opening = DebugAppInformationServices.Opening { model in
                model.page = .appPrivacy
                model.privacy.tab = .urls
            }
            return main(section: .appInformation) { $0.appInformation = information }
        default:
            return nil
        }
    }

    @MainActor
    private static func sheetScene(_ id: String) -> AnyView? {
        switch id {
        case "rp-loading":
            let base = DebugScreenshotsServices()
            base.documentDelay = hold
            let push = DebugScreenshotPushServices(script: DebugScreenshotUploadScript(), images: DebugScreenshotImages(fonts: base.fonts))
            var storePage = DebugStorePageServices()
            storePage.screenshots = DebugPushingScreenshotsServices(base: base, push: push)
            return main(section: .overview, pendingChanges: [], presentedSheet: .review) { $0.storePage = storePage }
        case "submit-loading":
            var release = DebugReleaseServices()
            release.laterStatusDelay = hold
            ReleaseDebugLaunch.pending = ReleaseDebugLaunch(opensSubmit: true)
            return main(section: .overview) { $0.release = release }
        case "assets-loading":
            let model = AssetLibraryModel(appID: DebugFixtures.AppID.lumen, appName: "Lumen Journal", manager: DebugAssetLibraryFiles(delay: hold))
            return AnyView(AssetLibrarySheet(model: model))
        case "paywall-loading":
            let entitlements = Entitlements(store: DebugProStore(offersDelay: hold))
            return AnyView(PaywallSheet(model: PaywallModel(context: .autopilot, entitlements: entitlements)) { _ in })
        default:
            return nil
        }
    }

    @MainActor
    private static func main(
        section: AppWorkspaceSection,
        events: InAppEventsStore? = nil,
        pendingChanges: [PendingChange] = DebugWorkspace.pendingChanges,
        presentedSheet: WorkspaceSheet? = nil,
        change: (inout WorkspaceServices) -> Void
    ) -> AnyView {
        var services = WorkspaceServices.debug
        change(&services)
        return AnyView(DebugMainScene(
            services: services, section: section, pendingChanges: pendingChanges, events: events ?? DebugInAppEventsData.store(),
            presentedSheet: presentedSheet
        ))
    }
}
#endif
