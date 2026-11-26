//
//  RefreshDebugAppListServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The sample apps for Refresh's DEBUG scenes: the first read answers at
/// once, so the window opens as usual; each later one (a Refresh) takes
/// `delay` and then fails with `failure`, or answers.
@MainActor
struct RefreshDebugAppListServices: AppListServices {
    var delay: Duration = .seconds(2)
    var failure: (any Error)?

    /// The reads answered in this launch.
    private static var reads = 0

    func apps() async throws -> [StoreApp] {
        defer { Self.reads += 1 }
        guard Self.reads > 0 else { return DebugFixtures.apps }
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        return DebugFixtures.apps
    }

    func teamName() async throws -> String? {
        nil
    }

    func iconURL(appID _: StoreApp.ID) async throws -> URL? {
        nil
    }
}
#endif
