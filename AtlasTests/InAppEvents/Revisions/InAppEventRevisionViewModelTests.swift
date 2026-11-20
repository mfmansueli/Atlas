//
//  InAppEventRevisionViewModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A revision of a written language on the event's page: the language
/// shows it (purple dot, "revision to review"), with Now and Suggested;
/// Accept queues only the texts it changes, Use and Edit does too and
/// puts the first one in to edit, Dismiss keeps what's written, and
/// Accept All Languages takes revisions with the rest.
@MainActor
@Suite("InAppEventsViewModel · revisions")
struct InAppEventRevisionViewModelTests {
    typealias Data = InAppEventsTestData
    typealias Streak = EventRevisionTestData

    private let queue = ChangeQueue()
    private let store = InAppEventsStore()

    private func makeModel(_ revisions: [InAppEventTextSuggestion], event: InAppEvent = Streak.event()) async -> InAppEventsViewModel {
        store.add(revisions, for: Data.app.id)
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices([event]), store: store, queue: queue)
        model.now = { Data.now }
        model.pageLocales = ["en-US", "pt-BR", "de-DE"]
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        model.select(event.id)
        model.localeCode = "en-US"
        return model
    }

    private var drafts: [String: [InAppEventField: String]] {
        InAppEventChangeBuilder(appID: Data.app.id).drafts(for: Streak.eventID, in: queue.changes(for: Data.app.id, section: .inAppEvents))
    }

    @Test func aWrittenLanguageShowsItsRevision() async throws {
        let model = await makeModel([Streak.revision("en-US")])
        let event = try #require(model.selectedEvent)
        let english = try #require(model.languages(of: event).first { $0.code == "en-US" })
        #expect(english.state == .revision)
        #expect(english.accessibilityText.hasSuffix("revision to review"))
        #expect(model.languages(of: event).first { $0.code == "de-DE" }?.state == .written)
        #expect(model.revision?.locale == "en-US")
        #expect(model.suggestion == nil)
        #expect(model.suggestedCount == 1)
        // The page's text is still what's written: Now.
        #expect(model.text(.longDescription) == Streak.sunday["en-US"])
        // A revision fills nothing App Review needs.
        #expect(!model.reviewItems(of: event).contains { $0.id == "primaryTexts" || $0.id == "languageTexts" })
    }

    @Test func acceptQueuesOnlyTheTextItChanges() async throws {
        let model = await makeModel([Streak.revision("en-US")])
        model.acceptSuggestion()
        #expect(drafts == ["en-US": [.longDescription: Streak.december["en-US"] ?? ""]])
        let change = try #require(queue.changes(for: Data.app.id, section: .inAppEvents).first)
        #expect(change.requests.count == 1)
        #expect(change.requests[0].method == .patch)
        #expect(change.requests[0].path == "/v1/appEventLocalizations/loc-en-US")
        let body = try #require(change.requests[0].body.flatMap { String(bytes: $0, encoding: .utf8) })
        #expect(body.contains("longDescription"))
        #expect(!body.contains("\"name\""))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(model.revision == nil)
        #expect(store.open(for: Data.app.id).isEmpty)
        #expect(model.toast?.text == "Accepted \(InAppEventChangeBuilder.localeName("en-US")). It’s in Review & Push.")
        #expect(model.text(.longDescription) == Streak.december["en-US"])
        #expect(model.text(.name) == Streak.names["en-US"])
    }

    @Test func useAndEditPutsTheFirstChangedTextInToEdit() async {
        let model = await makeModel([Streak.revision("en-US")])
        model.useAndEditRevision()
        #expect(model.focusedTextField == .longDescription)
        #expect(drafts["en-US"] == [.longDescription: Streak.december["en-US"] ?? ""])
        #expect(model.revision == nil)
    }

    @Test func dismissKeepsWhatsWritten() async throws {
        let model = await makeModel([Streak.revision("en-US")])
        model.dismissSuggestion()
        #expect(model.revision == nil)
        #expect(drafts.isEmpty)
        let event = try #require(model.selectedEvent)
        #expect(model.languages(of: event).first { $0.code == "en-US" }?.state == .written)
    }

    @Test func acceptAllLanguagesTakesEveryRevision() async throws {
        let model = await makeModel(["en-US", "pt-BR", "de-DE"].map { Streak.revision($0) })
        #expect(model.suggestedCount == 3)
        let event = try #require(model.selectedEvent)
        #expect(model.revisionCount(of: event) == 3)
        #expect(model.suggestedCount(of: event) == 0)
        #expect(model.tileNote(of: event).text.contains("Revision suggested for 3 languages"))
        model.acceptAllLanguages()
        #expect(drafts.count == 3)
        #expect(drafts["pt-BR"] == [.longDescription: Streak.december["pt-BR"] ?? ""])
        #expect(drafts["de-DE"] == [.longDescription: Streak.december["de-DE"] ?? ""])
        #expect(model.suggestedCount == 0)
        model.undoAccept()
        #expect(drafts.isEmpty)
        #expect(store.open(for: Data.app.id).count == 3)
    }

    @Test func acceptingReplacesThePersonsOwnQueuedText() async throws {
        let event = Streak.event()
        let localization = try #require(event.localization("en-US"))
        let builder = InAppEventChangeBuilder(appID: Data.app.id)
        try queue.upsert(#require(builder.fieldChange(.longDescription, to: "Mine, until Sunday.", in: localization, of: event, source: .you)))
        let model = await makeModel([Streak.revision("en-US")])
        #expect(model.revision != nil, "A revision of the person's queued text still shows")
        model.acceptSuggestion()
        let change = try #require(queue.changes(for: Data.app.id, section: .inAppEvents).first)
        #expect(change.newValue == Streak.december["en-US"])
        #expect(change.alternative == nil)
        model.undoAccept()
        #expect(queue.changes(for: Data.app.id, section: .inAppEvents).first?.newValue == "Mine, until Sunday.")
    }

    @Test func aRevisionThatChangesNothingDoesntShow() async {
        var event = Streak.event()
        event.localizations[0].longDescription = Streak.december["en-US"] ?? ""
        let model = await makeModel([Streak.revision("en-US")], event: event)
        #expect(model.revision == nil)
        #expect(model.languages(of: event).first { $0.code == "en-US" }?.state == .written)
    }

    @Test func anEventPastEditingShowsNoRevision() async {
        let model = await makeModel([Streak.revision("en-US")], event: Streak.event(state: .published))
        #expect(model.revision == nil)
    }
}
