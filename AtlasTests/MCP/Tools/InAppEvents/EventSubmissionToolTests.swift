//
//  EventSubmissionToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_event_submission`'s refusals: only a draft or rejected event
/// with everything App Review needs, and nothing waiting in Review & Push,
/// can be suggested for review. The person submits it.
@MainActor
@Suite("In-App Event submission over MCP")
struct EventSubmissionToolTests {
    typealias Data = InAppEventsTestData

    private func event(_ state: InAppEventState) -> InAppEvent {
        var event = Data.winter
        event.state = state
        return event
    }

    @Test func anEventWithAppReviewIsRefused() {
        for state in [InAppEventState.waitingForReview, .inReview, .approved, .published] {
            let reason = ProposeEventSubmissionTool.refusal(for: event(state), pending: 0, now: Data.now)
            #expect(reason?.contains("already with App Review") == true)
        }
    }

    @Test func anEndedEventIsRefusedWithWhatToDoInstead() {
        let reason = ProposeEventSubmissionTool.refusal(for: event(.past), pending: 0, now: Data.now)
        #expect(reason?.contains("propose_in_app_event") == true)
    }

    @Test func aDraftMissingWhatAppReviewNeedsSaysWhat() {
        let draft = event(.draft)
        let missing = draft.missing(now: Data.now)
        let reason = ProposeEventSubmissionTool.refusal(for: draft, pending: 0, now: Data.now)
        if missing.isEmpty {
            #expect(reason == nil)
        } else {
            #expect(reason?.contains("isn’t ready for App Review") == true)
        }
    }

    @Test func changesWaitingInReviewAndPushComeFirst() {
        let draft = event(.draft)
        guard draft.missing(now: Data.now).isEmpty else { return }
        let reason = ProposeEventSubmissionTool.refusal(for: draft, pending: 2, now: Data.now)
        #expect(reason?.hasPrefix("2 changes") == true)
    }
}
