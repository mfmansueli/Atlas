//
//  InAppEventsBadgeCountTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The purple count on In-App Events counts exactly what the section
/// shows: open suggestions, not stale, for events that still take texts,
/// and not hidden by texts waiting in Review & Push. Alba's sidebar said
/// 13 while every event page showed none.
@MainActor
@Suite("In-App Events · the section's count")
struct InAppEventsBadgeCountTests {
    typealias Data = InAppEventsTestData
    typealias Alba = AlbaWrittenSinceTestData

    private let store = InAppEventsStore()
    private let queue = ChangeQueue()

    private var changes: [PendingChange] { queue.changes(for: Data.app.id, section: .inAppEvents) }

    private func makeModel(_ events: [InAppEvent] = Data.events) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices(events), store: store, queue: queue)
        model.now = { Data.now }
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        return model
    }

    /// What the section shows over every event: languages suggested and
    /// written ones with a revision.
    private func shown(_ model: InAppEventsViewModel) -> Int {
        model.events.reduce(0) { $0 + model.suggestedCount(of: $1) + model.revisionCount(of: $1) }
    }

    @Test func beforeTheEventsAreReadEveryOpenSuggestionCounts() {
        store.add([Data.suggestion("ja"), Data.suggestion("fr-FR")], for: Data.app.id)
        #expect(store.count(for: Data.app.id) == 2)
        store.dismiss(Data.suggestion("ja").id, for: Data.app.id)
        #expect(store.count(for: Data.app.id) == 1)
    }

    @Test func onlyWhatTheSectionShowsCounts() async throws {
        let update = Data.suggestion("ja", event: "update")
        store.add([Data.suggestion("ja"), Data.suggestion("fr-FR"), Data.suggestion("it"), update], for: Data.app.id)
        let model = await makeModel()
        // The live update can't change: its suggestion is gone.
        #expect(store.open(for: Data.app.id, eventID: "update").isEmpty)
        #expect(store.count(for: Data.app.id, changes: changes) == 3)

        // The person writes Italian themselves: the suggestion hides.
        model.select("winter")
        let winter = try #require(model.selectedEvent)
        model.write([.name: "Riflessione d’inverno"], locale: "it", of: winter, source: .you)
        #expect(store.count(for: Data.app.id, changes: changes) == 2)
        // Dismissed: gone from the count too.
        model.localeCode = "fr-FR"
        model.dismissSuggestion()
        #expect(store.count(for: Data.app.id, changes: changes) == 1)
        #expect(store.count(for: Data.app.id, changes: changes) == shown(model))
    }

    @Test func aRevisionCountsWhileItWouldChangeSomething() async throws {
        let revision = EventRevisionTestData.revision("en-US")
        store.add([revision], for: Data.app.id)
        let model = await makeModel([EventRevisionTestData.event()])
        #expect(store.count(for: Data.app.id, changes: changes) == 1)
        // The person queued the same text the revision suggests: nothing
        // left to show.
        let event = try #require(model.selectedEvent)
        model.write([.longDescription: revision.longDescription], locale: "en-US", of: event, source: .you)
        #expect(store.count(for: Data.app.id, changes: changes) == 0)
        #expect(shown(model) == 0)
    }

    @Test func albasCountIsTheFourRevisionsItsPageShows() {
        store.add(Alba.suggestions, for: Alba.app.id)
        #expect(store.count(for: Alba.app.id) == 13)
        // The version's Submit sheet reads the events too.
        store.noteRead([Alba.event], for: Alba.app.id)
        #expect(store.count(for: Alba.app.id) == 4)
        let counts = SectionBadgeCounts(
            appID: Alba.app.id, suggestions: FieldSuggestionStore(),
            extras: SectionBadgeCounts.Extras(eventLanguages: store.count(for: Alba.app.id))
        )
        #expect(counts.text(for: .inAppEvents) == "4")
    }

    @Test func anEventThatCantChangeCountsNothing() {
        let count = InAppEventShownSuggestions(event: Data.gratitude, open: [Data.suggestion("ja", event: "gratitude")], drafts: [:]).count
        #expect(count == 0)
    }
}
