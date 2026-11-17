//
//  FakeInAppEventsServices.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// In-App Events without App Store Connect.
@MainActor
final class FakeInAppEventsServices: InAppEventsServices {
    var events: [InAppEvent]
    var error: AppStoreConnectError?
    private(set) var readCount = 0

    init(_ events: [InAppEvent] = InAppEventsTestData.events) {
        self.events = events
    }

    func events(for _: StoreApp) async throws -> [InAppEvent] {
        readCount += 1
        if let error { throw error }
        return events
    }
}
