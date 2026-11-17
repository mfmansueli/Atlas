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
/// - `nav-apps`: the app menu open; `nav-ph`: Reviews with the footer
///   following a phased release; `nav-free`: the Free plan.
/// - `nav-s`: the sidebar hidden, so the toolbar has the section menu and
///   the app's title; `nav-s-menu`: that menu open.
enum NavigationDebugScenes {
    static let ids = ["nav-ov", "nav-sp", "nav-ev", "nav-rv", "nav-an", "nav-apps", "nav-ph", "nav-free", "nav-s", "nav-s-menu"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "nav-apps":
            NavigationDebugLaunch.opensAppMenu = true
            return overview()
        case "nav-ph":
            return AnyView(DebugMainScene(
                services: ReleaseDebugScenes.services(.phased), section: .reviews, pendingChanges: [], release: DebugReleaseData.store(.phased)
            ))
        case "nav-free":
            return AnyView(DebugMainScene(section: .storePage, suggestions: SuggestionsDebugData.store(), isFree: true))
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
