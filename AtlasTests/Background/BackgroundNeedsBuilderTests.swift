//
//  BackgroundNeedsBuilderTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("BackgroundNeedsBuilder")
struct BackgroundNeedsBuilderTests {
    @Test func nothingWaitingIsNoLines() {
        let facts = BackgroundAppFacts(appID: "1", appName: "Lumen Journal")
        #expect(BackgroundNeedsBuilder.needs(for: [facts], namesApps: false).isEmpty)
    }

    @Test func autopilotFirstThenApprovalsReviewsFindingsSuggestions() {
        let lumen = BackgroundAppFacts(
            appID: "1", appName: "Lumen Journal", openSuggestions: 12, approvedVersion: "2.4", reviewReplies: 6,
            newFindings: 1, firstFindingTitle: "German page converts less"
        )
        let tempo = BackgroundAppFacts(appID: "2", appName: "Tempo", autopilotTurn: .choose)
        let needs = BackgroundNeedsBuilder.needs(for: [lumen, tempo], namesApps: true)
        #expect(needs.map(\.title) == [
            "Choose the look for Tempo’s screenshots",
            "Lumen Journal 2.4 was approved",
            "6 reviews need a reply",
            "1 new finding in Analytics",
            "12 suggestions to review",
        ])
        #expect(needs.map(\.destination) == [
            .section(.screenshots, appID: "2"),
            .version(appID: "1"),
            .section(.reviews, appID: "1"),
            .section(.analytics, appID: "1"),
            .section(.overview, appID: "1"),
        ])
        // With more than one app, the details say which.
        #expect(needs[2].detail == "Lumen Journal · Replies are suggested in each language")
        #expect(needs[3].detail == "Lumen Journal · German page converts less")
        #expect(Set(needs.map(\.id)).count == needs.count)
    }

    @Test func oneAppNeedsNoName() {
        let facts = BackgroundAppFacts(appID: "1", appName: "Lumen Journal", openSuggestions: 1, reviewReplies: 1)
        let needs = BackgroundNeedsBuilder.needs(for: [facts], namesApps: false)
        #expect(needs.map(\.title) == ["1 review needs a reply", "1 suggestion to review"])
        #expect(needs.map(\.detail) == ["Replies are suggested in each language", "Nothing changes until you accept it"])
    }

    /// Board 58: reviews Reply Automatically left for the person get their
    /// own line, before the suggested replies.
    @Test func autoReplyNeedsComeBeforeSuggestedReplies() {
        let facts = BackgroundAppFacts(appID: "1", appName: "Lumen Journal", reviewReplies: 3, autoReplyNeeds: 2)
        let needs = BackgroundNeedsBuilder.needs(for: [facts], namesApps: false)
        #expect(needs.map(\.title) == ["2 reviews need your reply", "3 reviews need a reply"])
        #expect(needs.first?.detail == "Reply Automatically left them for you")
        #expect(needs.first?.destination == .section(.reviews, appID: "1"))
    }

    @Test func autopilotWaitsOnThePersonOnlyAtItsTurns() {
        #expect(BackgroundNeedsBuilder.turn(for: .pick) == .pick)
        #expect(BackgroundNeedsBuilder.turn(for: .choose) == .choose)
        #expect(BackgroundNeedsBuilder.turn(for: .watchPreview) == .review)
        #expect(BackgroundNeedsBuilder.turn(for: .ready) == .review)
        for stage in [AutopilotStage.plan, .waiting, .capture, .design, .localize] {
            #expect(BackgroundNeedsBuilder.turn(for: stage) == nil)
        }
        #expect(BackgroundNeedsBuilder.title(for: .pick, appName: "Alba") == "Pick the captures for Alba’s screenshots")
        #expect(BackgroundNeedsBuilder.title(for: .review, appName: "Alba") == "Review and approve Alba’s screenshots")
    }
}
