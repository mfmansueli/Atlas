//
//  TranslationRunTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A translation run counts languages, not fields: a language counts once
/// its reviewer ends it, its texts arrive as they're written, and the run
/// finishes with the last language.
@MainActor
@Suite("Translation run progress")
struct TranslationRunTests {
    private let appID = "app1"
    private let client = "Claude Code"
    private let languages: [StoreLocale] = [.german, .french, .japanese]

    private func started() -> (FieldSuggestionStore, SuggestionRun) {
        let store = FieldSuggestionStore()
        let plan = languages.map { SuggestionTarget.storePage($0, .subtitle) }
        let run = store.startRun(appID: appID, client: client, plan: plan, kind: .translation, languages: languages.map(\.code))
        return (store, run)
    }

    private func send(_ locale: StoreLocale, to store: FieldSuggestionStore, run: SuggestionRun) {
        store.add(appID: appID, target: .storePage(locale, .subtitle), value: "\(locale.code) subtitle", reason: "", source: .assistant(client: client), runID: run.id)
    }

    @Test func itCountsLanguagesDone() {
        let (store, run) = started()
        #expect(store.run?.progressText == "Translating · 0 of 3 languages")
        #expect(store.run?.countText == "0 of 3 languages")
        #expect(store.run?.title == "Translating")
        send(.german, to: store, run: run)
        #expect(store.run?.received == 1)
        #expect(store.run?.progressText == "Translating · 0 of 3 languages")
        store.endLanguage("de-DE", inRun: run.id)
        #expect(store.run?.progressText == "Translating · 1 of 3 languages")
        #expect(store.run?.fraction == 1.0 / 3.0)
    }

    @Test func everyTextArrivingDoesntFinishItBeforeTheReviews() {
        let (store, run) = started()
        for locale in languages {
            send(locale, to: store, run: run)
        }
        #expect(store.run?.phase == .running)
        for locale in languages {
            store.endLanguage(locale.code, inRun: run.id)
        }
        #expect(store.run?.phase == .finished)
        #expect(store.run?.finishedText == "Claude Code sent 3 suggestions in 3 languages.")
    }

    @Test func anEndedLanguageStopsShowingWhatsComing() {
        let (store, run) = started()
        let japanese = SuggestionTarget.storePage(.japanese, .subtitle)
        #expect(store.run?.isComing(japanese) == true)
        store.endLanguage("ja", inRun: run.id)
        #expect(store.run?.isComing(japanese) == false)
        #expect(store.run?.comingCount(in: [SuggestionScope.storePage(.japanese)]) == 0)
    }

    @Test func aLanguageTheRunDoesntHaveChangesNothing() {
        let (store, run) = started()
        #expect(store.endLanguage("pt-BR", inRun: run.id) == nil)
        #expect(store.endLanguage("de-DE", inRun: "run_99") == nil)
        #expect(store.run?.languagesDone == 0)
    }

    @Test func captionsOnlyRunsWaitForTheirLanguages() {
        let store = FieldSuggestionStore()
        let run = store.startRun(appID: appID, client: client, plan: [], kind: .translation, languages: ["de-DE"])
        #expect(run.phase == .running)
        #expect(store.run?.progressText == "Translating · 0 of 1 language")
    }

    @Test func suggestEverythingIsCountedAsBefore() {
        let store = FieldSuggestionStore()
        let run = store.startRun(appID: appID, client: client, plan: [.storePage(.german, .subtitle)])
        #expect(run.kind == .everything)
        #expect(store.run?.progressText == "Suggesting everything · 0 of 1")
        send(.german, to: store, run: run)
        #expect(store.run?.phase == .finished)
    }

    /// The Autopilot button (and part A's bar) reads the countable line.
    @Test func theAutopilotButtonSaysTheLanguagesDone() {
        let inputs = WorkspaceAutopilotState.Inputs(askSubject: "Store Page", translating: "Translating · 4 of 12 languages")
        #expect(WorkspaceAutopilotState(inputs) == .running("Translating · 4 of 12 languages"))
        #expect(WorkspaceAutopilotState(inputs).announcementKey == "running:Translating")
    }
}
