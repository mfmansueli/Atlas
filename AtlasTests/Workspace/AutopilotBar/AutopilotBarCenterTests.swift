//
//  AutopilotBarCenterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What the Autopilot bar keeps besides the chat (board 80): the request a
/// button sent, Done until it's shown, Earlier today, Try Again after a
/// failure, and the strips closed with ✕.
@MainActor
@Suite("Autopilot bar · center")
struct AutopilotBarCenterTests {
    private static let appID = "1"

    private func request(_ title: String = "Suggest Texts", action: WorkspaceAutopilotAction = .suggestTexts) -> AutopilotBarRequest {
        AutopilotBarRequest(appID: Self.appID, title: title, action: action, section: .storePage, sentAt: .now)
    }

    @Test func aSentRequestFinishesAsDoneAndUnderEarlierToday() throws {
        let center = AutopilotBarCenter()
        center.send(request())
        #expect(center.sent[Self.appID] != nil)
        center.finish(
            appID: Self.appID, subject: "Store Page · German", text: "Its suggestions are marked in purple.", result: "6 suggestions", section: .overview
        )
        #expect(center.sent[Self.appID] == nil)
        let done = try #require(center.done[Self.appID])
        #expect(done.what == "Suggest Texts · Store Page · German")
        #expect(done.title == "Done · Suggest Texts · Store Page · German")
        // Show goes where it was sent from.
        #expect(done.section == .storePage)
        #expect(center.earlierToday(for: Self.appID).map(\.id) == [done.id])
    }

    @Test func aPagesOwnRequestFinishesUnderItsSubject() throws {
        let center = AutopilotBarCenter()
        center.finish(appID: Self.appID, subject: "In-App Events · Winter", text: "Done.", section: .inAppEvents)
        let done = try #require(center.done[Self.appID])
        #expect(done.what == "In-App Events · Winter")
        #expect(done.section == .inAppEvents)
    }

    @Test func aFailedRequestIsKeptForTryAgain() {
        let center = AutopilotBarCenter()
        center.send(request())
        center.finish(appID: Self.appID, subject: "Store Page", text: "Claude Code stopped.", failed: true, section: .storePage)
        #expect(center.done[Self.appID] == nil)
        #expect(center.failed[Self.appID]?.action == .suggestTexts)
        #expect(center.earlierToday(for: Self.appID).isEmpty)
        center.forgetFailure(appID: Self.appID)
        #expect(center.failed[Self.appID] == nil)
    }

    @Test func aRequestThatStartedNothingLeavesNoBubble() {
        let center = AutopilotBarCenter()
        center.send(request("Make Screenshots", action: .makeScreenshots))
        center.withdraw(appID: Self.appID)
        #expect(center.sent[Self.appID] == nil)
    }

    @Test func closingTheStripOrOpeningTheBarClearsDone() throws {
        let center = AutopilotBarCenter()
        center.finish(appID: Self.appID, subject: "Store Page", text: "", section: .storePage)
        let key = try #require(center.done[Self.appID]?.key)
        center.dismiss(key, appID: Self.appID)
        #expect(center.done[Self.appID] == nil)
        #expect(center.dismissedKeys(for: Self.appID).contains(key))
        center.finish(appID: Self.appID, subject: "Store Page", text: "", section: .storePage)
        center.opened(appID: Self.appID)
        #expect(center.done[Self.appID] == nil)
        // Still under Earlier today.
        #expect(center.earlierToday(for: Self.appID).count == 2)
    }

    @Test func earlierTodayKeepsTodaysNewestFirstAndAtMostSix() {
        let center = AutopilotBarCenter()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        center.now = { now }
        for index in 0..<8 {
            now = now.addingTimeInterval(60)
            center.finish(appID: Self.appID, subject: "Run \(index)", text: "", section: .storePage)
        }
        let earlier = center.earlierToday(for: Self.appID)
        #expect(earlier.count == AutopilotBarCenter.earlierLimit)
        #expect(earlier.first?.what == "Run 7")
        // Tomorrow, nothing from today.
        now = now.addingTimeInterval(86400 * 2)
        #expect(center.earlierToday(for: Self.appID).isEmpty)
    }

    @Test func sendingAgainForgetsTheLastFailureAndDone() {
        let center = AutopilotBarCenter()
        center.finish(appID: Self.appID, subject: "Store Page", text: "", section: .storePage)
        center.send(request())
        #expect(center.done[Self.appID] == nil)
        #expect(center.failed[Self.appID] == nil)
    }
}
