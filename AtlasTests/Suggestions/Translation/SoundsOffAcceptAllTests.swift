//
//  SoundsOffAcceptAllTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 77 in Accept All Languages: what sounds off to a native speaker
/// starts unticked with its reason, and accepting without asking never
/// takes it.
@MainActor
@Suite("Sounds off in Accept All")
struct SoundsOffAcceptAllTests {
    private let app = StorePageContentFixtures.app
    private let queue = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let claude = SuggestionSource.assistant(client: "Claude Code")

    private let off = SuggestionLayers(
        gloss: "Weekly look back",
        translation: TranslationReading(
            sounds: .off,
            notes: [TranslationNote(phrase: "Rückblick der Woche", natural: "Wochenrückblick", why: "Reads like a word-for-word copy.")],
            natural: "Wochenrückblick"
        )
    )

    private func item(_ id: String, sounds: SoundsNatural?) -> AcceptAllItem {
        AcceptAllItem(id: id, title: "Subtitle", source: claude, current: "", suggested: "x", reason: "Why.", sounds: sounds)
    }

    @Test func soundsOffStartsUnticked() {
        let group = AcceptAllGroup(id: "de-DE", title: "German", items: [
            item("a", sounds: .native), item("b", sounds: .off), item("c", sounds: .translated), item("d", sounds: nil),
        ])
        let selection = AcceptAllSelection(kind: .storePage, groups: [group])
        #expect(selection.selectedCount == 3)
        #expect(group.soundsOffCount == 1)
    }

    @Test func theRowSaysWhyItIsLeftOut() {
        let row = item("b", sounds: nil).reading(off, lines: .meansAndSounds)
        #expect(row.soundsOff)
        #expect(row.means == "Weekly look back")
        #expect(row.soundsOffReason?.contains("Wochenrückblick") == true)
        // Keywords: MEANS only, so no pill and nothing left out.
        let keywords = item("k", sounds: nil).reading(off, lines: .meansOnly)
        #expect(keywords.sounds == nil)
        #expect(!keywords.soundsOff)
        #expect(keywords.means == "Weekly look back")
    }

    @Test func theNaturalVersionIsNoLongerLeftOut() throws {
        let used = try #require(off.usingNaturalVersion(over: "Rückblick der Woche"))
        let row = item("b", sounds: nil).reading(used.layers, lines: .meansAndSounds)
        #expect(!row.soundsOff)
        #expect(row.soundsOffReason == nil)
    }

    @Test func acceptingWithoutAskingLeavesSoundsOffForThePerson() async {
        let model = StorePageViewModel(app: app, services: FakeStorePageServices(), queue: queue, suggestions: store)
        await model.load()
        let before = model.value(.whatsNew, in: .german)
        store.add(
            appID: app.id, target: .storePage(.german, .whatsNew), value: "Rückblick der Woche", reason: "Translated.", source: claude, layers: off
        )
        store.add(appID: app.id, target: .storePage(.german, .promotionalText), value: "Schreib jeden Tag ein wenig.", reason: "Translated.", source: claude)
        model.acceptAllLanguages(withoutAsking: true)
        #expect(model.value(.promotionalText, in: .german) == "Schreib jeden Tag ein wenig.")
        #expect(model.value(.whatsNew, in: .german) == before)
        #expect(model.shownSuggestion(.whatsNew, in: .german) != nil)
    }

    @Test func afterUseNaturalVersionAcceptTakesWhatIsOnTheCard() async throws {
        let model = StorePageViewModel(app: app, services: FakeStorePageServices(), queue: queue, suggestions: store)
        await model.load()
        store.add(
            appID: app.id, target: .storePage(.german, .whatsNew), value: "Rückblick der Woche", reason: "Translated.", source: claude, layers: off
        )
        let suggestion = try #require(model.shownSuggestion(.whatsNew, in: .german))
        model.useNaturalVersion(suggestion)
        #expect(model.toast?.canUndo == true)
        let swapped = try #require(model.shownSuggestion(.whatsNew, in: .german))
        #expect(swapped.value == "Wochenrückblick")

        // Undo from the toast puts the first text back on the card.
        model.undoToast()
        #expect(model.shownSuggestion(.whatsNew, in: .german)?.value == "Rückblick der Woche")

        model.useNaturalVersion(suggestion)
        let natural = try #require(model.shownSuggestion(.whatsNew, in: .german))
        model.acceptSuggestion(natural)
        #expect(model.value(.whatsNew, in: .german) == "Wochenrückblick")
    }
}
