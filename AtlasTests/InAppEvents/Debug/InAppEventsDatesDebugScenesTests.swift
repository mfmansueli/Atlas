//
//  InAppEventsDatesDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The dates' DEBUG scenes show what their UI tests look for, at the
/// scenes' clock (Nov 16, 12:00 GMT).
@MainActor
@Suite("In-App Events · dates scenes")
struct InAppEventsDatesDebugScenesTests {
    typealias Scenes = InAppEventsDatesDebugScenes

    private static let now = DebugReviewsData.today

    @Test func sevenDaysOfGratitudeIsReadyButForItsCardsDate() {
        let event = Scenes.sevenDays
        #expect(event.reviewNeeds(now: Self.now) == [.publishStartPassed])
        #expect(InAppEventChangeBuilder.datesEditProblem(of: event) == nil)
        #expect(event.dates?.suggestedPublishStart(now: Self.now, calendar: .gmtGregorian) == DebugInAppEventsData.date(month: 11, day: 18, hour: 12))
    }

    @Test func theQueuedSceneHoldsDatesThatFixIt() throws {
        let change = try #require(Scenes.queuedFix().first)
        #expect(!change.isBlocked)
        #expect(InAppEventChangeBuilder.datesValue(in: change)?.broken(now: Self.now).isEmpty == true)
    }

    @Test func theSoonSceneWarnsWithoutANeed() {
        let event = Scenes.soonMood
        #expect(event.reviewNeeds(now: Self.now).isEmpty)
        #expect(event.dates?.warnings(now: Self.now) == [.eventStartsSoon])
    }

    @Test func theScenesAreNamedOnce() {
        let all = Scenes.ids + ReleaseEventsDebugScenes.ids + InAppEventsDeepLinkDebugScenes.ids
        #expect(Set(all).count == all.count)
        #expect(ReleaseEventsDebugScenes.ids.contains("rel-sheet-ev-dates"))
    }
}
#endif
