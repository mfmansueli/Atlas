//
//  DebugAppListServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// `AppListServices` for DEBUG scenes: canned apps, or `error`, optionally
/// after `delay` (a long one keeps the loading skeleton on screen). The
/// sample apps draw their own icons; `teamName` is what App Store Connect
/// would call the team.
@MainActor
struct DebugAppListServices: AppListServices {
    var apps: [StoreApp] = DebugFixtures.apps
    var error: AppStoreConnectError?
    var delay: Duration?
    var teamName: String?
    /// Apps App Store Connect lists only from the second read on, as if
    /// made since the first sync, for Add App (`nav-addapp`).
    var madeLater: [StoreApp] = []

    /// Whether `apps()` answered once already in this launch.
    private static var hasRead = false

    func apps() async throws -> [StoreApp] {
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        defer { Self.hasRead = true }
        return Self.hasRead ? (apps + madeLater).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : apps
    }

    func teamName() async throws -> String? {
        teamName
    }

    func iconURL(appID _: StoreApp.ID) async throws -> URL? {
        nil
    }
}
#endif
