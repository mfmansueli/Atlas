//
//  NavigationDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of the sidebar navigation (`-AtlasDebugScene
/// <id>`), as on the design's boards 41–43.
///
/// - `nav-ov`, `nav-sp` (Store Page in German), `nav-ev`, `nav-rv`,
///   `nav-an`: a section selected in the sidebar.
/// - `nav-accounts`: Accounts and keys open; `nav-addapp`: Add App open,
///   with two apps made since the first sync; `nav-accounts-free`:
///   Accounts and keys on the Free plan, Add Another Key… with the PRO chip.
/// - `nav-apps`: the app menu open; `nav-ph`: Reviews with the footer
///   following a phased release; `nav-free`: the Free plan.
/// - `nav-s`: the sidebar hidden, so the toolbar has the section menu and
///   the app's title; `nav-s-menu`: that menu open.
/// - `nav-prefetch`: Overview with the other sections read ahead, the
///   Store Page and App Information taking `prefetchDelay` to read.
enum NavigationDebugScenes {
    static let ids = [
        "nav-ov", "nav-sp", "nav-ev", "nav-rv", "nav-an", "nav-apps", "nav-accounts", "nav-accounts-free", "nav-addapp", "nav-ph",
        "nav-free", "nav-s", "nav-s-menu", "nav-prefetch",
    ]

    /// How long each slow read of `nav-prefetch` takes.
    static let prefetchDelay: Duration = .seconds(4)

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "nav-apps":
            NavigationDebugLaunch.opensAppMenu = true
            return overview()
        case "nav-accounts":
            NavigationDebugLaunch.opensMenuSheet = "accounts"
            return overview()
        case "nav-accounts-free":
            NavigationDebugLaunch.opensMenuSheet = "accounts"
            return AnyView(DebugMainScene(
                services: ReleaseDebugScenes.services(.prepare), section: .overview, suggestions: SuggestionsDebugData.store(),
                release: DebugReleaseData.store(.prepare), isFree: true
            ))
        case "nav-addapp":
            NavigationDebugLaunch.opensMenuSheet = "addApp"
            var services = ReleaseDebugScenes.services(.prepare)
            services.appList = DebugAppListServices(madeLater: madeLater)
            return AnyView(DebugMainScene(
                services: services, section: .overview, suggestions: SuggestionsDebugData.store(), release: DebugReleaseData.store(.prepare)
            ))
        case "nav-ph":
            return AnyView(DebugMainScene(
                services: ReleaseDebugScenes.services(.phased), section: .reviews, pendingChanges: [], release: DebugReleaseData.store(.phased)
            ))
        case "nav-free":
            return AnyView(DebugMainScene(section: .storePage, suggestions: SuggestionsDebugData.store(), isFree: true))
        case "nav-prefetch":
            var services = WorkspaceServices.debug
            var storePage = DebugStorePageServices()
            storePage.delay = prefetchDelay
            services.storePage = storePage
            services.appInformation = DebugAppInformationServices(delay: prefetchDelay)
            return AnyView(DebugMainScene(services: services, section: .overview, prefetchesSections: true))
        case "nav-s", "nav-s-menu":
            NavigationDebugLaunch.hidesSidebar = true
            NavigationDebugLaunch.opensSectionMenu = id == "nav-s-menu"
            return SuggestionsDebugScenes.view(for: "sp-de")
        default:
            return sectionScene(id)
        }
    }

    /// One section selected in the sidebar, as its own scenes show it.
    @MainActor
    private static func sectionScene(_ id: String) -> AnyView? {
        switch id {
        case "nav-ov": overview()
        case "nav-sp": SuggestionsDebugScenes.view(for: "sp-de")
        case "nav-ev": InAppEventsDebugScenes.view(for: "ev")
        case "nav-rv": ReviewsDebugScenes.view(for: "rv")
        case "nav-an": AnalyticsDebugScenes.view(for: "an-funnel")
        default: nil
        }
    }

    /// The two apps App Store Connect lists after the first sync.
    private static let madeLater = [
        StoreApp(id: "6450000901", name: "Pebble Weather", bundleID: "dev.northpier.pebble", primaryLocale: "en-US"),
        StoreApp(id: "6450000902", name: "Tidepool Sounds", bundleID: "dev.northpier.tidepool", primaryLocale: "en-US"),
    ]

    /// Overview with Lumen 1.4 before it's submitted and the suggestions
    /// that give the sidebar its counts.
    @MainActor
    private static func overview() -> AnyView {
        AnyView(DebugMainScene(
            services: ReleaseDebugScenes.services(.prepare), section: .overview, suggestions: SuggestionsDebugData.store(),
            release: DebugReleaseData.store(.prepare)
        ))
    }
}
#endif
