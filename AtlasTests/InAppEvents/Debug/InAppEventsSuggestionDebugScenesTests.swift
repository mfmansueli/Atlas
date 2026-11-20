//
//  InAppEventsSuggestionDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The DEBUG scenes of an assistant's suggestions beside what's there
/// hold what their UI tests look for, at the scenes' clock (Nov 16,
/// 12:00 GMT).
@MainActor
@Suite("In-App Events · suggestion scenes")
struct InAppEventsSuggestionDebugScenesTests {
    typealias Scenes = InAppEventsSuggestionDebugScenes

    private static let now = DebugReviewsData.today

    @Test func thePersonsDatesHoldClaudesBesideThem() throws {
        let change = try #require(Scenes.datesBesideThePersons().first)
        #expect(change.source == .you)
        let alternative = try #require(change.alternative)
        #expect(alternative.source == .assistant(client: "Claude Code"))
        #expect(alternative.blockedReason == nil)
        let theirs = try #require(InAppEventChangeBuilder.datesValue(in: change))
        let suggested = try #require(InAppEventChangeBuilder.datesValue(in: alternative.requests))
        #expect(suggested.publishStart == theirs.publishStart)
        #expect(suggested.eventStart != theirs.eventStart)
        #expect(suggested.broken(now: Self.now).isEmpty)
    }

    @Test func theRevisionChangesOnlyTheEnglishLongDescription() throws {
        let english = try #require(Scenes.sundayEvent.localization("en-US"))
        #expect(english.longDescription.hasSuffix("by Sunday."))
        #expect(Scenes.revision.revisedFields == [.longDescription])
        #expect(Scenes.revision.longDescription.hasSuffix("by November 26."))
        #expect(TextWordDiff(from: english.longDescription, to: Scenes.revision.longDescription).addedWords == ["November 26"])
        #expect(!Scenes.revision.isStale(in: Scenes.sundayEvent))
        #expect(Scenes.revision.overLimit == nil)
    }

    @Test func theScenesAreNamedOnce() {
        let all = Scenes.ids + InAppEventsDatesDebugScenes.ids + InAppEventsDebugScenes.ids + InAppEventsDeepLinkDebugScenes.ids
            + ReleaseEventsDebugScenes.ids
        #expect(Set(all).count == all.count)
        #expect(Scenes.ids == ["ev-dates-suggested", "ev-text-revision"])
    }
}
#endif
