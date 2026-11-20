//
//  InAppEventDismissAllTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Dismiss All beside Accept All Languages: every suggestion and revision
/// the event shows goes at once, written texts stay, other events keep
/// theirs, and the toast's Undo brings them all back.
@MainActor
@Suite("In-App Events · Dismiss All")
struct InAppEventDismissAllTests {
    typealias Data = InAppEventsTestData
    typealias Alba = AlbaWrittenSinceTestData

    private let store = InAppEventsStore()
    private let queue = ChangeQueue()

    private func makeModel(_ events: [InAppEvent], app: StoreApp = Data.app) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: app, services: FakeInAppEventsServices(events), store: store, queue: queue)
        model.now = { Data.now }
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        return model
    }

    @Test func dismissAllTakesEverySuggestionOfTheEventAndUndoBringsThemBack() async {
        var other = Data.winter
        other.id = "spring"
        store.add([Data.suggestion("ja"), Data.suggestion("fr-FR"), Data.suggestion("ja", event: "spring")], for: Data.app.id)
        let model = await makeModel([Data.winter, other])
        model.select("winter")
        #expect(model.suggestedCount == 2)

        model.dismissAllLanguages()
        #expect(model.suggestedCount == 0)
        #expect(store.open(for: Data.app.id, eventID: "winter").isEmpty)
        #expect(store.open(for: Data.app.id, eventID: "spring").count == 1)
        #expect(store.count(for: Data.app.id) == 1)
        #expect(model.toast?.text == "Dismissed 2 languages for Winter Reflection Challenge.")
        #expect(model.toast?.canUndo == true)
        #expect(queue.changes(for: Data.app.id).isEmpty)

        model.undoAccept()
        #expect(model.suggestedCount == 2)
        #expect(store.count(for: Data.app.id) == 3)
        #expect(model.toast == nil)
    }

    @Test func dismissAllTakesRevisionsToo() async throws {
        store.add(Alba.suggestions, for: Alba.app.id)
        let model = await makeModel([Alba.event], app: Alba.app)
        #expect(model.suggestedCount == 4)
        model.dismissAllLanguages()
        #expect(model.suggestedCount == 0)
        #expect(store.count(for: Alba.app.id) == 0)
        let event = try #require(model.selectedEvent)
        // What's written stays as it is.
        #expect(model.languages(of: event).allSatisfy { $0.state == .written })
        #expect(model.toast?.text == "Dismissed 4 languages for \(Alba.written(.name, "en-US")).")
    }

    @Test func nothingShownNothingDismissed() async {
        let model = await makeModel([Data.winter])
        model.dismissAllLanguages()
        #expect(model.toast == nil)
        #expect(model.undo == nil)
    }
}
