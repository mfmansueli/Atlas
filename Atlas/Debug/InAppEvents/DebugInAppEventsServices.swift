//
//  DebugInAppEventsServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// In-App Events without App Store Connect: Lumen's three sample events;
/// the other apps have none.
@MainActor
struct DebugInAppEventsServices: InAppEventsServices {
    var error: AppStoreConnectError?
    /// No events at all, for the empty scene.
    var isEmpty = false
    /// Lumen's events instead of the sample ones.
    var events: [InAppEvent]?
    /// How long the events take to read, for ev-loading.
    var delay: Duration?

    func events(for app: StoreApp) async throws -> [InAppEvent] {
        if let delay { try await Task.sleep(for: delay) }
        if let error { throw error }
        return app.id == DebugFixtures.AppID.lumen && !isEmpty ? events ?? DebugInAppEventsData.events : []
    }

    func results(for event: InAppEvent, of _: StoreApp) async -> InAppEventResults? {
        event.id == DebugInAppEventsData.gratitudeID ? DebugInAppEventsData.gratitudeResults : nil
    }
}
#endif
