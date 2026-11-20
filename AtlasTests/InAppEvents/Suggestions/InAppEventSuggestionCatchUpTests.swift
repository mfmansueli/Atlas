//
//  InAppEventSuggestionCatchUpTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Suggestions App Store Connect caught up with, settled when the events
/// are read: a new language's texts already written as suggested are done
/// and leave the archive; written otherwise, they become a revision of the
/// texts that differ, saying they came before. Alba's real case: 13 new
/// languages of "New Year, New Mindset", all written since.
@MainActor
@Suite("In-App Events · suggestions written since")
struct InAppEventSuggestionCatchUpTests {
    typealias Data = InAppEventsTestData
    typealias Alba = AlbaWrittenSinceTestData

    /// Winter with German written whole, as `texts` say.
    private static func winter(german texts: [InAppEventField: String]) -> InAppEvent {
        var event = Data.winter
        event.localizations[1].name = texts[.name] ?? ""
        event.localizations[1].shortDescription = texts[.shortDescription] ?? ""
        event.localizations[1].longDescription = texts[.longDescription] ?? ""
        return event
    }

    private static let germanAsSuggested: [InAppEventField: String] = [.name: "Name", .shortDescription: "Short de-DE", .longDescription: "Long de-DE"]

    // MARK: - One suggestion

    @Test func writtenAsSuggestedIsDone() {
        let suggestion = Data.suggestion("de-DE")
        #expect(suggestion.caughtUp(with: Self.winter(german: Self.germanAsSuggested)) == nil)
    }

    @Test func writtenOtherwiseIsARevisionOfTheTextsThatDiffer() throws {
        var texts = Self.germanAsSuggested
        texts[.name] = "Winter-Reflexion"
        let event = Self.winter(german: texts)
        let suggestion = Data.suggestion("de-DE")
        #expect(suggestion.isStale(in: event))
        let revision = try #require(suggestion.caughtUp(with: event))
        #expect(revision.isRevision)
        #expect(revision.revisedFields == [.name])
        #expect(revision.name == "Name")
        #expect(revision.shortDescription.isEmpty && revision.longDescription.isEmpty)
        #expect(revision.why == "Suggested before this language was written: Reads naturally.")
        #expect(revision.id == suggestion.id)
        #expect(revision.source == suggestion.source && revision.date == suggestion.date)
        // It would change something now: not stale, and settled once.
        #expect(!revision.isStale(in: event))
        #expect(revision.caughtUp(with: event) == revision)
    }

    @Test func aLanguageNotWrittenWholeKeepsItsSuggestion() {
        let suggestion = Data.suggestion("de-DE")
        // Winter's German has only its name.
        #expect(suggestion.caughtUp(with: Data.winter) == suggestion)
        #expect(Data.suggestion("ja").caughtUp(with: Data.winter) == Data.suggestion("ja"))
    }

    @Test func aRevisionWhoseTextsAreWrittenIsDone() {
        let revision = EventRevisionTestData.revision("en-US")
        var event = EventRevisionTestData.event()
        #expect(revision.caughtUp(with: event) == revision)
        event.localizations[0].longDescription = EventRevisionTestData.december["en-US"] ?? ""
        #expect(revision.caughtUp(with: event) == nil)
    }

    // MARK: - The store, when the events are read

    @Test func readingTheEventsDropsDoneOnesEvenDismissed() {
        let store = InAppEventsStore()
        let sameGerman = Data.suggestion("de-DE")
        store.add([sameGerman, Data.suggestion("ja")], for: Data.app.id)
        store.dismiss(sameGerman.id, for: Data.app.id)
        store.noteRead([Self.winter(german: Self.germanAsSuggested), Data.update, Data.gratitude], for: Data.app.id)
        #expect(store.archive(for: Data.app.id).suggestions.map(\.locale) == ["ja"])
        #expect(store.archive(for: Data.app.id).dismissed.isEmpty)
    }

    @Test func albasThirteenLanguagesSettleIntoFourRevisions() async throws {
        let store = InAppEventsStore()
        store.add(Alba.suggestions, for: Alba.app.id)
        // Before Atlas read the events this launch: every one counts.
        #expect(store.count(for: Alba.app.id) == 13)

        let model = InAppEventsViewModel(app: Alba.app, services: FakeInAppEventsServices([Alba.event]), store: store, queue: ChangeQueue())
        model.now = { Alba.now }
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()

        let left = store.archive(for: Alba.app.id).suggestions
        #expect(Set(left.map(\.locale)) == Set(Alba.differing.keys))
        for suggestion in left {
            #expect(suggestion.revisedFields == Alba.differing[suggestion.locale])
            #expect(suggestion.why == "Suggested before this language was written: \(Alba.why)")
            #expect(suggestion.date == Alba.suggestedAt)
            for field in suggestion.fields {
                #expect(suggestion.text(field) == Alba.suggested(field, suggestion.locale))
            }
        }
        // The count is what the page shows: four revisions to look at.
        #expect(store.count(for: Alba.app.id) == 4)
        let event = try #require(model.selectedEvent)
        let revised = model.languages(of: event).filter { $0.state == .revision }.map(\.code)
        #expect(Set(revised) == Set(Alba.differing.keys))
        #expect(model.suggestedCount == 4)
        #expect(model.suggestionsTitle == "4 languages suggested by Claude Code")

        // Brazil's revision: Now is App Store Connect's name, Suggested Claude Code's.
        model.localeCode = "pt-BR"
        let revision = try #require(model.revision)
        #expect(revision.fields == [.name])
        #expect(model.text(.name) == Alba.written(.name, "pt-BR"))
        #expect(revision.text(.name) == Alba.suggested(.name, "pt-BR"))

        // Reading again changes nothing more.
        await model.load(force: true)
        #expect(store.archive(for: Alba.app.id).suggestions == left)
    }

    @Test func theSettledArchiveIsSaved() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "InAppEventsCatchUp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = InAppEventsStore(directory: directory)
        store.add(Alba.suggestions, for: Alba.app.id)
        store.noteRead([Alba.event], for: Alba.app.id)
        let reopened = InAppEventsStore(directory: directory)
        let kept = reopened.archive(for: Alba.app.id).suggestions
        #expect(kept.count == 4)
        #expect(kept.filter(\.isRevision).count == 4)
    }
}
