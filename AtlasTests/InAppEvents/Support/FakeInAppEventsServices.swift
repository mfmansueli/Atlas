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
    /// How many reads throw `error` before the next ones work; nil throws
    /// it on every read.
    var failingReads: Int?
    private(set) var readCount = 0

    init(_ events: [InAppEvent] = InAppEventsTestData.events) {
        self.events = events
    }

    func events(for _: StoreApp) async throws -> [InAppEvent] {
        readCount += 1
        if let error, failingReads.map({ readCount <= $0 }) ?? true { throw error }
        return events
    }
}
