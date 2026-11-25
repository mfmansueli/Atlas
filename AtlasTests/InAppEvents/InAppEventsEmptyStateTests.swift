//
//  InAppEventsEmptyStateTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 74 · 3: In-App Events is empty with no event and none queued,
/// and then the toolbar leads with Suggest an Event….
@MainActor
@Suite("In-App Events empty state")
struct InAppEventsEmptyStateTests {
    typealias Data = InAppEventsTestData

    private let queue = ChangeQueue()
    private let store = InAppEventsStore()

    private func makeModel(_ events: [InAppEvent]) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices(events), store: store, queue: queue)
        model.now = { Data.now }
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        return model
    }

    @Test func noEventIsEmptyAndAsksForASuggestion() async {
        let model = await makeModel([])
        #expect(model.showsEmptyState)
        #expect(model.autopilotDetail == .noEvents)
    }

    @Test func eventsAreNotEmpty() async {
        let model = await makeModel(Data.events)
        #expect(!model.showsEmptyState)
        #expect(model.autopilotDetail != .noEvents)
    }

    @Test func beforeTheFirstReadItIsntEmpty() {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices([]), store: store, queue: queue)
        #expect(!model.showsEmptyState)
        #expect(model.autopilotDetail == nil)
    }

    @Test func aFailedReadIsntEmpty() async {
        let services = FakeInAppEventsServices([])
        services.error = .server(statusCode: 500, detail: "Later.")
        let model = InAppEventsViewModel(app: Data.app, services: services, store: store, queue: queue)
        await model.load()
        #expect(!model.showsEmptyState)
    }
}
