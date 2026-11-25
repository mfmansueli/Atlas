//
//  NaturalVersionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 77's Use Natural Version: the card's text and MEANS swap to the
/// natural version, Undo puts the first one back, and Accept takes what's
/// on the card.
@MainActor
@Suite("Use Natural Version")
struct NaturalVersionTests {
    private let polishSubtitle = SuggestionLayers(
        gloss: "Mood journal and inspirations",
        translation: TranslationReading(
            sounds: .off,
            notes: [TranslationNote(phrase: "inspiracje", natural: "podpowiedzi", why: "Means inspiration, not writing prompts.")],
            natural: "Dziennik nastroju i podpowiedzi",
            naturalMeans: "Mood journal and prompts",
            drift: [MeaningDrift(phrase: "inspirations", original: "prompts")]
        )
    )

    @Test func usingItSwapsTheTextAndMeans() throws {
        let used = try #require(polishSubtitle.usingNaturalVersion(over: "Dziennik nastroju i inspiracje"))
        #expect(used.value == "Dziennik nastroju i podpowiedzi")
        #expect(used.layers.means == "Mood journal and prompts")
        #expect(used.layers.translation?.sounds == .native)
        #expect(used.layers.translation?.usesNaturalVersion == true)
        #expect(used.layers.translation?.shownNotes.isEmpty == true)
        #expect(!used.layers.soundsOff)
        // Once on, there's nothing more to use.
        #expect(used.layers.usingNaturalVersion(over: used.value) == nil)
    }

    @Test func undoPutsTheFirstTextBack() throws {
        let used = try #require(polishSubtitle.usingNaturalVersion(over: "Dziennik nastroju i inspiracje"))
        let undone = try #require(used.layers.undoingNaturalVersion())
        #expect(undone.value == "Dziennik nastroju i inspiracje")
        #expect(undone.layers == polishSubtitle)
        #expect(polishSubtitle.undoingNaturalVersion() == nil)
    }

    @Test func withoutANaturalVersionThereIsNothingToUse() {
        let layers = SuggestionLayers(gloss: "x", translation: TranslationReading(sounds: .translated))
        #expect(layers.usingNaturalVersion(over: "y") == nil)
        #expect(layers.translation?.offersNaturalVersion == false)
    }

    @Test func theSummaryIsAtlassOwnWords() {
        #expect(TranslationReading(sounds: .native).summary == "Reads naturally.")
        let two = TranslationReading(sounds: .translated, notes: [
            TranslationNote(phrase: "a", natural: "b", why: "c"), TranslationNote(phrase: "d", natural: "e", why: "f"),
            TranslationNote(phrase: "g", natural: "h", why: "i"),
        ])
        #expect(two.summary == "3 phrases follow the original too closely.")
        #expect(two.shownNotes.count == 2)
        #expect(TranslationReading(notes: []).summary == nil)
    }

    @Test func theStoreSwapsAndKeepsIt() throws {
        let store = FieldSuggestionStore()
        let added = store.add(
            appID: "1", target: .storePage(.polish, .subtitle), value: "Dziennik nastroju i inspiracje", reason: "Translated.",
            source: .assistant(client: "Claude Code"), layers: polishSubtitle
        ).suggestion
        let used = try #require(store.useNaturalVersion(added.id))
        #expect(used.value == "Dziennik nastroju i podpowiedzi")
        #expect(store.suggestion(id: added.id)?.value == "Dziennik nastroju i podpowiedzi")
        #expect(store.useNaturalVersion(added.id) == nil)
        let undone = try #require(store.undoNaturalVersion(added.id))
        #expect(undone.value == "Dziennik nastroju i inspiracje")
        #expect(undone.layers == polishSubtitle)
    }

    @Test func aDecidedSuggestionDoesntSwap() {
        let store = FieldSuggestionStore()
        let added = store.add(
            appID: "1", target: .storePage(.polish, .subtitle), value: "Dziennik nastroju i inspiracje", reason: "Translated.",
            source: .assistant(client: "Claude Code"), layers: polishSubtitle
        ).suggestion
        store.dismiss([added.id])
        #expect(store.useNaturalVersion(added.id) == nil)
    }

    @Test func savedReadingsComeBack() throws {
        let data = try JSONEncoder().encode(polishSubtitle)
        #expect(try JSONDecoder().decode(SuggestionLayers.self, from: data) == polishSubtitle)
        // Layers saved before board 77 have no reading.
        let old = try JSONDecoder().decode(SuggestionLayers.self, from: Data(#"{"gloss":"Your week"}"#.utf8))
        #expect(old.translation == nil)
    }

    @Test func marksFindThePhrase() {
        #expect(TranslationMarks.found(in: "Dziennik nastroju i inspiracje", phrases: ["inspiracje", "missing"]) == ["inspiracje"])
    }
}
