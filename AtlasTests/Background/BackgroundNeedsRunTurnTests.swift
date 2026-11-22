//
//  BackgroundNeedsRunTurnTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The menu bar's and toolbar's "Needs you" for a guided run: Review &
/// approve waits on the person until Approve All, after which the set
/// waits in Review & Push with every other change, and nothing in
/// Autopilot does.
@MainActor
@Suite("BackgroundNeedsBuilder · a run's turn")
struct BackgroundNeedsRunTurnTests {
    @Test func aReadyRunWaitsOnThePersonUntilApproveAll() {
        let ready = AutopilotTestFixtures.run(.ready)
        #expect(BackgroundNeedsBuilder.turn(for: ready) == .review)

        var approved = ready
        approved.guidedReview = AutopilotGuidedReview(approved: GuidedReviewPart.allCases, approvedAllAt: AutopilotTestFixtures.now)
        #expect(BackgroundNeedsBuilder.turn(for: approved) == nil, "Approved: it waits in Review & Push, not on Autopilot")

        var pushed = ready
        pushed.guidedReview = AutopilotGuidedReview(pushedAt: AutopilotTestFixtures.now)
        #expect(BackgroundNeedsBuilder.turn(for: pushed) == nil, "Pushed from the sheet before board 57")
    }

    /// Approvals alone, before Approve All, still leave the person's turn.
    @Test func partsApprovedOneByOneStillWait() {
        var run = AutopilotTestFixtures.run(.ready)
        run.guidedReview = AutopilotGuidedReview(approved: [.screenshots])
        #expect(BackgroundNeedsBuilder.turn(for: run) == .review)
    }

    @Test func otherStagesKeepTheirTurn() {
        #expect(BackgroundNeedsBuilder.turn(for: AutopilotTestFixtures.run(.choose)) == .choose)
        #expect(BackgroundNeedsBuilder.turn(for: AutopilotTestFixtures.run(.capture)) == nil)
    }
}
#endif
