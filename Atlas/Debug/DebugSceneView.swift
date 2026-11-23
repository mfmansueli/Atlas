//
//  DebugSceneView.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Renders a `DebugScene` id with canned services:
///
/// - `apps`, `apps-empty`, `apps-error`, `lib-loading`: the main window with
///   the sample apps (Lumen Journal selected), none, a failed load, or the
///   first sync still running.
/// - `apps-unnamed`: the sample apps under a key the person hasn't named;
///   App Store Connect calls its team Northpier Studio.
/// - `overview`, `overview-keep`: Lumen Journal's overview, or Tempo
///   Metronome's with Keep my prices.
/// - `overview-shots-loading`: Lumen Journal's overview, its live
///   screenshots taking 8 seconds each to download.
///
/// Ids it doesn't know go to each area's own list (`ConnectDebugScenes`,
/// `SettingsDebugScenes`, `ReviewPushDebugScenes`, `PricingDebugScenes`, `AppPriceDebugScenes`, `RetentionDebugScenes`,
/// `StorePageDebugScenes`, `AppInformationDebugScenes`,
/// `ScreenshotsDebugScenes`, `ScreenshotsPushDebugScenes`, `ExtrasPushDebugScenes`,
/// `ScreenshotsProposalsDebugScenes`, `ScreenshotsHandDebugScenes`, `AssistantDebugScenes`,
/// `SuggestionsDebugScenes`, `AssistDebugScenes`, `EverythingDebugScenes`,
/// `NewLanguagesDebugScenes`, `StudioDebugScenes`, `ClaudeCodeDebugScenes`,
/// `ProductPagesDebugScenes`, `TourDebugScenes`, `AutopilotButtonDebugScenes`, `MenuBarDebugScenes`,
/// `DesignSystemDebugScenes`).
struct DebugSceneView: View {
    let id: String

    var body: some View {
        switch id {
        case "apps", "overview":
            DebugMainScene()
        case "apps-badges":
            DebugMainScene(suggestions: SuggestionsDebugData.store())
        case "overview-keep":
            DebugMainScene(selectedAppID: DebugFixtures.AppID.tempo)
        case "overview-shots-loading":
            DebugMainScene(services: services { $0.storePage = Self.slowScreenshots() })
        case "apps-empty":
            DebugMainScene(services: services { $0.appList = DebugAppListServices(apps: []) }, selectedAppID: nil)
        case "apps-error":
            DebugMainScene(services: services { $0.appList = DebugAppListServices(error: .unauthorized) }, selectedAppID: nil)
        case "lib-loading":
            DebugMainScene(services: services { $0.appList = DebugAppListServices(delay: .seconds(3600)) })
        case "apps-unnamed":
            DebugMainScene(services: services { $0.appList = DebugAppListServices(teamName: DebugFixtures.northpier.name) }, unnamedKey: true)
        default:
            if let scene = Self.scene(for: id) {
                scene
            } else {
                ContentUnavailableView("Unknown debug scene", systemImage: "questionmark.square.dashed", description: Text(id))
            }
        }
    }

    /// The first area's scene with this id.
    private static func scene(for id: String) -> AnyView? {
        let areas: [@MainActor (String) -> AnyView?] = [
            ConnectDebugScenes.view(for:),
            SettingsDebugScenes.view(for:),
            HelpDebugScenes.view(for:),
            ReviewPushDebugScenes.view(for:),
            PricingDebugScenes.view(for:),
            AppPriceDebugScenes.view(for:),
            RetentionDebugScenes.view(for:),
            StorePageDebugScenes.view(for:),
            AppInformationDebugScenes.view(for:),
            ScreenshotsDebugScenes.view(for:),
            ScreenshotsPushDebugScenes.view(for:),
            ExtrasPushDebugScenes.view(for:),
            ScreenshotsProposalsDebugScenes.view(for:),
            ScreenshotsHandDebugScenes.view(for:),
            AssistantDebugScenes.view(for:),
            SuggestionsDebugScenes.view(for:),
            AssistDebugScenes.view(for:),
            EverythingDebugScenes.view(for:),
            NewLanguagesDebugScenes.view(for:),
            StudioDebugScenes.view(for:),
            ClaudeCodeDebugScenes.view(for:),
            AnalyticsDebugScenes.view(for:),
            ReviewsDebugScenes.view(for:),
            AutoReplyDebugScenes.view(for:),
            ReleaseDebugScenes.view(for:),
            ReleaseEventsDebugScenes.view(for:),
            InAppEventsDebugScenes.view(for:),
            InAppEventsDeepLinkDebugScenes.view(for:),
            InAppEventsDatesDebugScenes.view(for:),
            InAppEventsSuggestionDebugScenes.view(for:),
            EventArtworkDebugScenes.view(for:),
            ProductPagesDebugScenes.view(for:),
            NavigationDebugScenes.view(for:),
            TourDebugScenes.view(for:),
            AutopilotButtonDebugScenes.view(for:),
            MenuBarDebugScenes.view(for:),
            DesignSystemDebugScenes.view(for:),
        ]
        return areas.lazy.compactMap { $0(id) }.first
    }

    /// The sample store pages, their live screenshots slow to download.
    private static func slowScreenshots() -> DebugStorePageServices {
        let screenshots = DebugScreenshotsServices()
        screenshots.liveImageDelay = .seconds(8)
        screenshots.drawsPushedLiveSets = true
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        return storePage
    }

    private func services(_ change: (inout WorkspaceServices) -> Void) -> WorkspaceServices {
        var services = WorkspaceServices.debug
        change(&services)
        return services
    }
}
#endif
