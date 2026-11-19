//
//  EventArtworkStudioTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The runs behind board 47: concepts arriving one by one, a change that
/// takes the place of its concept, Claude Code ending early, and the runs
/// kept on this Mac across launches.
@MainActor
@Suite("Event artwork studio")
struct EventArtworkStudioTests {
    typealias Test = EventArtworkStudioTestData

    private let directory = EventArtworkTestFiles.directory()

    @Test func theLastConceptMovesTheRunToChoose() throws {
        let studio = EventArtworkStudio()
        studio.begin(Test.run())
        try studio.add(Test.concept("a", in: directory), to: Test.key)
        try studio.add(Test.concept("b", isPick: true, in: directory), to: Test.key)
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.step == .making)
        try studio.add(Test.concept("c", in: directory), to: Test.key)
        let run = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(run.step == .choose)
        #expect(run.concepts.map(\.id) == ["a", "b", "c"])
        #expect(run.picked?.id == "b")
    }

    @Test func aConceptWithATakenIdGetsTheNextLetter() throws {
        let studio = EventArtworkStudio()
        studio.begin(Test.run())
        try studio.add(Test.concept("a", in: directory), to: Test.key)
        let run = try studio.add(Test.concept("a", in: directory), to: Test.key)
        #expect(run?.concepts.map(\.id) == ["a", "b"])
        #expect(try studio.add(Test.concept("x", in: directory), to: EventArtworkRun.Key(appID: "1", eventID: "2")) == nil)
    }

    @Test func aChangeTakesItsConceptsPlaceAndGoesToCheck() throws {
        let studio = EventArtworkStudio()
        var run = try Test.run(concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        run.revisingID = "a"
        run.revisionRequest = "Warmer"
        studio.begin(run)
        var revised = try Test.concept("z", in: directory)
        revised.name = "Warmer Path"
        let updated = try #require(studio.add(revised, to: Test.key, replacing: "a"))
        #expect(updated.step == .check)
        #expect(updated.concepts.map(\.id) == ["a", "b"])
        #expect(updated.concepts[0].name == "Warmer Path")
        #expect(updated.concepts[0].isPick)
        #expect(updated.revisingID == nil)
        #expect(updated.pickedID == "a")
    }

    @Test func claudeCodeEndingEarlyShowsWhatArrived() throws {
        let studio = EventArtworkStudio()
        try studio.begin(Test.run(concepts: [Test.concept("a", in: directory)]))
        studio.runEnded(Test.key)
        let run = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(run.step == .choose)
        #expect(run.expectedCount == 1)
    }

    /// Nothing arrived: back to the Brief with the person's words, never
    /// shown as an error.
    @Test func nothingArrivedGoesBackToTheBrief() throws {
        let studio = EventArtworkStudio()
        var run = Test.run()
        run.isHidden = true
        run.brief = "My words"
        studio.begin(run)
        studio.runEnded(Test.key)
        let ended = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(ended.step == .brief)
        #expect(!ended.isHidden)
        #expect(ended.brief == "My words")
    }

    @Test func onlyTheRunsOwnClaudeCodeEndsIt() {
        let studio = EventArtworkStudio()
        var run = Test.run()
        let id = UUID()
        run.claudeRunID = id
        studio.begin(run)
        func session(_ runID: UUID, purpose: ClaudeCodeRunPurpose) -> ClaudeCodeRun {
            ClaudeCodeRun(
                id: runID, appID: Test.key.appID, appName: "Lumen", purpose: purpose, prompt: "", workingDirectory: "/tmp", startedAt: .now
            )
        }
        studio.claudeRunEnded(session(UUID(), purpose: .eventArtworkConcepts(eventID: Test.key.eventID)))
        studio.claudeRunEnded(session(id, purpose: .eventArtwork(eventID: Test.key.eventID)))
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.step == .making)
        studio.claudeRunEnded(session(id, purpose: .eventArtworkConcepts(eventID: Test.key.eventID)))
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.step == .brief)
    }

    @Test func theMenuBarSeesMakingAndReadyRuns() throws {
        let studio = EventArtworkStudio()
        studio.begin(Test.run())
        #expect(studio.makingRuns.count == 1)
        #expect(studio.readyRuns.isEmpty)
        studio.update(Test.key) { run in
            run.step = .choose
            run.isHidden = true
        }
        #expect(studio.readyRuns.isEmpty)
        try studio.add(Test.concept("a", in: directory), to: Test.key)
        #expect(studio.makingRuns.isEmpty)
        #expect(studio.readyRuns.count == 1)
    }

    /// The event's page on screen: what's in there is seen, so the menu
    /// bar has no dot for it.
    @Test func thePageOnScreenSeesTheConcepts() throws {
        let studio = EventArtworkStudio()
        var run = try Test.run(step: .choose, concepts: [Test.concept("a", in: directory)])
        run.isHidden = true
        studio.begin(run)
        #expect(studio.readyRuns.count == 1)
        studio.watch(Test.key)
        #expect(studio.readyRuns.isEmpty)
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.isHidden == false)
        studio.watch(nil)
        #expect(studio.readyRuns.isEmpty)
    }

    /// Ask for Changes: the new pair takes the concept's place, marked
    /// changed, and is shown.
    @Test func aChangedConceptKeepsItsPlace() throws {
        let studio = EventArtworkStudio()
        var run = try Test.run(step: .making, concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        run.revisingID = "a"
        run.revisionRequest = "Warmer."
        studio.begin(run)
        let changed = try Test.concept("new", in: directory)
        try #require(studio.add(changed, to: Test.key, replacing: "a"))
        let after = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(after.concepts.map(\.id) == ["a", "b"])
        #expect(after.concepts[0].isPick)
        #expect(after.concepts[0].revisedAt == changed.arrivedAt)
        #expect(after.concepts[1].revisedAt == nil)
        #expect(after.revisingID == nil)
        #expect(after.pickedID == "a")
        #expect(after.step == .check)
    }

    @Test func runsAreKeptAcrossLaunches() throws {
        let folder = EventArtworkTestFiles.directory()
        let first = EventArtworkStudio(directory: folder)
        var run = try Test.run(step: .choose, concepts: [Test.concept("a", in: directory)])
        run.pickedID = "a"
        run.makesMotion = true
        first.begin(run)
        let second = EventArtworkStudio(directory: folder)
        #expect(second.run(appID: Test.key.appID, eventID: Test.key.eventID) == run)
        second.remove(Test.key)
        #expect(EventArtworkStudio(directory: folder).runs.isEmpty)
    }

    /// The Claude Code Atlas started ended with the last launch.
    @Test func aDrawingRunFromTheLastLaunchMovesOn() throws {
        let folder = EventArtworkTestFiles.directory()
        var run = try Test.run(concepts: [Test.concept("a", in: directory)])
        run.claudeRunID = UUID()
        EventArtworkStudio(directory: folder).begin(run)
        #expect(EventArtworkStudio(directory: folder).run(appID: Test.key.appID, eventID: Test.key.eventID)?.step == .choose)
        var pasted = Test.run()
        pasted.claudeRunID = nil
        EventArtworkStudio(directory: folder).begin(pasted)
        #expect(EventArtworkStudio(directory: folder).run(appID: Test.key.appID, eventID: Test.key.eventID)?.step == .making)
    }

    // MARK: - Make Them Move

    @Test func motionReplacesEachConceptThenGoesToChoose() throws {
        let studio = EventArtworkStudio()
        var run = try Test.run(concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        run.animatingIDs = ["a", "b"]
        run.makesMotion = true
        studio.begin(run)
        var moving = try Test.concept("z", in: directory)
        moving.videos = moving.stills.map { EventArtworkImage(kind: $0.kind, fileID: $0.fileID, path: $0.path, isVideo: true) }
        let first = try #require(studio.add(moving, to: Test.key, replacing: "a"))
        #expect(first.step == .making)
        #expect(first.animatingIDs == ["b"])
        #expect(first.concepts[0].videos.count == 2)
        #expect(first.concepts[0].isPick)
        let last = try #require(studio.add(moving, to: Test.key, replacing: "b"))
        #expect(last.step == .choose)
        #expect(last.animatingIDs == nil)
        #expect(last.concepts.map(\.id) == ["a", "b"])
    }

    @Test func claudeCodeEndingDuringMotionKeepsWhatMoved() throws {
        let studio = EventArtworkStudio()
        var run = try Test.run(concepts: [Test.concept("a", in: directory), Test.concept("b", in: directory)])
        run.animatingIDs = ["b"]
        studio.begin(run)
        studio.runEnded(Test.key)
        let ended = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(ended.step == .choose)
        #expect(ended.animatingIDs == nil)
        #expect(ended.concepts.count == 2)
    }

    /// Runs saved before Make Them Move still decode.
    @Test func aRunSavedWithoutMotionFieldsDecodes() throws {
        let run = try Test.run(concepts: [Test.concept("a", in: directory)])
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(run)) as? [String: Any])
        json["animatingIDs"] = nil
        let decoded = try JSONDecoder().decode(EventArtworkRun.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.animatingIDs == nil)
        #expect(!decoded.isAnimating)
    }
}
