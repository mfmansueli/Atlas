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

    func events(for app: StoreApp) async throws -> [InAppEvent] {
        if let error { throw error }
        return app.id == DebugFixtures.AppID.lumen && !isEmpty ? DebugInAppEventsData.events : []
    }

    func results(for event: InAppEvent, of _: StoreApp) async -> InAppEventResults? {
        event.id == DebugInAppEventsData.gratitudeID ? DebugInAppEventsData.gratitudeResults : nil
    }
}
#endif
