//
//  DebugReleaseState.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The version a release DEBUG scene's buttons act on: Cancel Submission,
/// Release Now and Pause change it, as App Store Connect would.
@MainActor
final class DebugReleaseState {
    var phase: DebugReleasePhase
    /// What was submitted last, for tests.
    private(set) var submittedPlans: [SubmissionPlan] = []

    init(_ phase: DebugReleasePhase = .prepare) {
        self.phase = phase
    }

    func note(_ plan: SubmissionPlan) {
        submittedPlans.append(plan)
        phase = .waiting
    }
}
#endif
