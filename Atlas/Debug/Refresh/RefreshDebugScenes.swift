//
//  RefreshDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Refresh's DEBUG scenes (`-AtlasDebugScene <id>`), as board 90 draws it:
///
/// - `rf-slow`: the Store Page; each Refresh takes 2 seconds, so the arrow
///   turns and the button stays off meanwhile.
/// - `rf-fail`: each Refresh fails (Apple answers 503): an amber dot, and
///   "Couldn’t update · Details…" at the end of the status line.
/// - `rf-off`: each Refresh finds no network: a grey dot and "Offline ·
///   from 14:32".
/// - `rf-side`: the sidebar hidden, so Refresh is in the toolbar after the
///   section menu.
enum RefreshDebugScenes {
    static let ids = ["rf-slow", "rf-fail", "rf-off", "rf-side"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "rf-slow":
            return scene(RefreshDebugAppListServices())
        case "rf-fail":
            return scene(RefreshDebugAppListServices(delay: .milliseconds(600), failure: AppStoreConnectError.server(statusCode: 503, detail: nil)))
        case "rf-off":
            return scene(RefreshDebugAppListServices(delay: .milliseconds(600), failure: URLError(.notConnectedToInternet)))
        case "rf-side":
            NavigationDebugLaunch.hidesSidebar = true
            return scene(RefreshDebugAppListServices())
        default:
            return nil
        }
    }

    @MainActor
    private static func scene(_ appList: RefreshDebugAppListServices) -> AnyView {
        var services = WorkspaceServices.debug
        services.appList = appList
        return AnyView(DebugMainScene(services: services, section: .storePage))
    }
}
#endif
