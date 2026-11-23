//
//  EventArtworkPanelStateTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Artwork panel beside the event's preview (board 40): what it says
/// and which buttons it offers with nothing made, while Claude
/// draws, with concepts ready, once one is used, while changing it, and
/// for an event that's over.
@MainActor
@Suite("Event artwork panel")
struct EventArtworkPanelStateTests {
    typealias Test = EventArtworkStudioTestData

    private let directory = EventArtworkTestFiles.directory()

    private func concepts(_ ids: [String], pick: String = "a") throws -> [EventArtworkConcept] {
        try ids.map { try Test.concept($0, isPick: $0 == pick, in: directory) }
    }

    private func state(
        _ run: EventArtworkRun?, isChanging: Bool = false, usedIsQueued: Bool = false, missing: [InAppEventMedia.Kind] = [],
        canEdit: Bool = true, isOver: Bool = false, preview: EventArtworkConcept.ID? = nil
    ) -> EventArtworkPanelState {
        EventArtworkPanelState.make(
            run: run, isChanging: isChanging, usedIsQueued: usedIsQueued, missing: missing,
            event: .init(languages: 12, canEdit: canEdit, isOver: isOver),
            preview: preview.flatMap { id in run?.concepts.first { $0.id == id } }
        )
    }

    @Test func nothingMadeAndAnImageMissingAsksForIt() {
        let state = state(nil, missing: [.details])
        #expect(state.phase == .missing([.details]))
        #expect(state.line == "Event details image missing")
        #expect(state.tone == .warning)
        #expect(state.detail == "Needed to submit. Claude can make a matching pair from the event’s text.")
        #expect(state.showsMake)
        #expect(state.showsChooseFiles)
        #expect(!state.showsView)
        #expect(!state.isRows)
    }

    @Test func anEventWithBothImagesOffersToViewOrReplaceThem() {
        let state = state(nil)
        #expect(state.phase == .complete)
        #expect(state.line == "Event card and event details")
        #expect(state.detail == "1920 × 1080 and 1080 × 1920 · the same pair in every language")
        #expect(state.showsView)
        #expect(state.showsReplace)
        #expect(!state.showsMake)
        let over = self.state(nil, canEdit: false, isOver: true)
        #expect(over.detail == "As they were on the App Store.")
        #expect(!over.showsReplace)
    }

    @Test func whileDrawingTheRowsFillInOneByOne() throws {
        var run = try Test.run(step: .making, concepts: concepts(["a"]))
        run.pickedID = nil
        let state = state(run, missing: [.details], preview: "a")
        #expect(state.phase == .drawing(ready: 1, total: 3))
        #expect(state.line == "Claude is drawing · 1 of 3 ready")
        #expect(abs(state.progress - 0.3867) < 0.001)
        #expect(state.rows.map(\.state) == [.ready, .drawing, .waiting])
        #expect(state.rows.map(\.isDisabled) == [false, true, true])
        #expect(state.rows.first?.tag == .pick)
        #expect(state.showsStop)
        #expect(state.showsView)
        #expect(!state.showsUse)
        #expect(!state.showsMake)
    }

    @Test func readyConceptsAreOfferedInPurple() throws {
        let run = try Test.run(step: .choose, concepts: concepts(["a", "b", "c"]))
        let state = state(run, missing: [.details], preview: "b")
        #expect(state.phase == .ready(count: 3))
        #expect(state.line == "3 concepts are ready")
        #expect(state.tone == .suggestion)
        #expect(state.rows.map(\.isPreviewed) == [false, true, false])
        #expect(state.showsUse)
        #expect(state.showsView)
        #expect(!state.showsStop)
        #expect(!state.showsChange)
    }

    @Test func theUsedPairIsShownUntilChange() throws {
        var run = try Test.run(step: .check, concepts: concepts(["a", "b", "c"]))
        run.usedConceptID = "a"
        run.usedAt = InAppEventsTestData.now
        let used = state(run, usedIsQueued: true, missing: [.details], preview: "a")
        #expect(used.phase == .used(name: "Concept a", kinds: 2, moves: false))
        #expect(used.line == "“Concept a”")
        #expect(used.detail == "Event card and event details, a matching pair for all 12 languages · in Review & Push")
        #expect(!used.isRows)
        #expect(used.showsChange)
        #expect(used.showsView)
        #expect(!used.showsUse)
        let changing = state(run, isChanging: true, usedIsQueued: true, missing: [.details], preview: "c")
        #expect(changing.phase == .changing)
        #expect(changing.line == "Choose another concept")
        #expect(changing.rows.first?.tag == .inUse)
        #expect(changing.showsKeepCurrent)
        #expect(changing.showsUse)
        // Previewing the one in use: nothing to use.
        #expect(!state(run, isChanging: true, usedIsQueued: true, preview: "a").showsUse)
    }

    @Test func aConceptBeingChangedIsBusyAndCanBeStopped() throws {
        var run = try Test.run(step: .making, concepts: concepts(["a", "b", "c"]))
        run.revisingID = "b"
        let state = state(run, missing: [.details], preview: "a")
        #expect(state.phase == .ready(count: 3))
        #expect(state.rows.map(\.state) == [.ready, .redrawing, .ready])
        #expect(state.rows[1].isBusy)
        #expect(state.showsStop)
        #expect(!state.showsAddMotion)
    }

    @Test func aChangedConceptIsTaggedUpdated() throws {
        var run = try Test.run(step: .check, concepts: concepts(["a", "b"]))
        run.concepts[1].revisedAt = InAppEventsTestData.now
        let state = state(run, missing: [.details])
        #expect(state.rows.map(\.tag) == [.pick, .updated])
    }
}
