//
//  GuidedPushOutcomeTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Done step after Approve All: the set waits in Review & Push, which
/// is the only place it's pushed from; Done follows that push in one line
/// and says "Sent" only when every image and extra went.
@Suite("GuidedPushOutcome")
struct GuidedPushOutcomeTests {
    private typealias Tally = GuidedPushOutcome.Tally

    /// Approve All (board 57) put the set in Review & Push: it waits there
    /// until a push for the app goes, and Done opens Review & Push.
    @Test func approvedWaitsInReviewAndPush() {
        let outcome = GuidedPushOutcome.make(images: nil, extras: nil)
        #expect(outcome == .approved)
        #expect(outcome.title == "Waiting in Review & Push")
        #expect(outcome.detail?.contains("top right") == true)
        #expect(outcome.detail?.contains("with your other changes") == true)
        #expect(outcome.opensReviewPush)
        #expect(outcome.reviewPushTitle == "Open Review & Push…")
    }

    /// A push from Review & Push is followed, not shown: its progress and
    /// Try Again are in Review & Push, which Show Progress… opens.
    @Test func aPushFromReviewAndPushShowsItsProgressThere() {
        let running = Tally(total: 4, done: 1, isRunning: true)
        let finished = Tally(total: 2, done: 2, isRunning: false)
        let outcome = GuidedPushOutcome.make(images: running, extras: finished)
        #expect(outcome == .sending)
        #expect(outcome.title == "Pushing from Review & Push")
        #expect(outcome.detail == "Its progress is in Review & Push, top right.")
        #expect(outcome.opensReviewPush)
        #expect(outcome.reviewPushTitle == "Show Progress…")
    }

    @Test func everythingSentIsSent() {
        let images = Tally(total: 4, done: 4, isRunning: false)
        #expect(GuidedPushOutcome.make(images: images, extras: nil) == .sent)
        #expect(GuidedPushOutcome.make(images: images, extras: Tally(total: 1, done: 1, isRunning: false)) == .sent)
        #expect(GuidedPushOutcome.sent.title == "Sent to the App Store")
        #expect(GuidedPushOutcome.sent.detail == nil, "Done writes what was sent")
        #expect(!GuidedPushOutcome.sent.opensReviewPush)
    }

    /// Going offline leaves rows "not sent", with no failure among them;
    /// Try Again is Review & Push's.
    @Test func anythingNotSentIsPartly() {
        let images = Tally(total: 4, done: 4, isRunning: false)
        #expect(GuidedPushOutcome.make(images: Tally(total: 4, done: 3, isRunning: false), extras: nil) == .partly)
        #expect(GuidedPushOutcome.make(images: images, extras: Tally(total: 2, done: 0, isRunning: false)) == .partly)
        #expect(GuidedPushOutcome.partly.title == "Not everything was sent")
        #expect(GuidedPushOutcome.partly.detail?.contains("stays in Review & Push, where you can try again") == true)
        #expect(GuidedPushOutcome.partly.opensReviewPush)
    }

    /// A run pushed from the sheet before board 57, after a relaunch: Done
    /// can't tell how it ended.
    @Test func aRunPushedFromTheSheetBeforeCantTell() {
        let outcome = GuidedPushOutcome.make(images: nil, extras: nil, pushedFromSheet: true)
        #expect(outcome == .unknown)
        #expect(outcome.title == "Sent from this Mac")
        #expect(outcome.detail?.contains("can’t tell how it ended") == true)
    }
}
#endif
