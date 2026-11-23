//
//  ReleaseProposalRulesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// What can be proposed for Lumen Journal 1.4 in each state: exactly what
/// the version card offers, and a refusal that says what's possible.
@MainActor
@Suite("Release proposal rules")
struct ReleaseProposalRulesTests {
    @Test(arguments: [
        (DebugReleasePhase.prepare, [ReleaseProposal.Action.submit]),
        (.waiting, [.cancelSubmission]),
        (.review, []),
        (.pending, [.release]),
        (.phased, [.pausePhasedRelease, .completePhasedRelease]),
        (.paused, [.resumePhasedRelease, .completePhasedRelease]),
        (.rejected, [.submit, .resubmit]),
        (.live, []),
    ])
    func eachStateAllowsWhatTheCardOffers(phase: DebugReleasePhase, actions: [ReleaseProposal.Action]) {
        #expect(ReleaseProposalRules.possibleActions(in: DebugReleaseData.status(phase)) == actions)
    }

    @Test func aRefusalSaysWhatIsPossibleInstead() throws {
        let waiting = DebugReleaseData.status(.waiting)
        let release = try #require(ReleaseProposalRules.problem(.release, in: waiting))
        #expect(release.contains("Pending Developer Release"))
        #expect(release.hasSuffix("Possible now: cancel_submission."))

        let inReview = DebugReleaseData.status(.review)
        let cancel = try #require(ReleaseProposalRules.problem(.cancelSubmission, in: inReview))
        #expect(cancel.contains("App Review has started"))
        #expect(cancel.hasSuffix("Nothing can be done until App Review finishes."))

        let paused = DebugReleaseData.status(.paused)
        #expect(ReleaseProposalRules.problem(.pausePhasedRelease, in: paused)?.contains("already paused") == true)
        #expect(ReleaseProposalRules.problem(.resumePhasedRelease, in: paused) == nil)
    }

    /// A rejected version whose submission isn't open with App Review is
    /// sent again from the Submit sheet: resubmit says to propose submit.
    @Test func aRejectedVersionWithoutItsSubmissionIsSubmittedAnew() throws {
        var rejected = DebugReleaseData.status(.rejected)
        rejected.submission = nil
        #expect(ReleaseProposalRules.possibleActions(in: rejected) == [.submit])
        let problem = try #require(ReleaseProposalRules.problem(.resubmit, in: rejected))
        #expect(problem.contains("propose submit"))
    }

    @Test func eachProposalRunsTheCardsAction() {
        #expect(ReleaseProposal.Action.submit.releaseAction == nil)
        for action in ReleaseProposal.Action.allCases {
            guard let card = action.releaseAction else { continue }
            #expect(ReleaseProposal.Action(card) == action)
        }
        #expect(ReleaseProposal.Action.completePhasedRelease.releaseAction == .releaseToEveryone)
    }
}
#endif
