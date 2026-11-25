//
//  DebugReleaseServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Submitting and releasing without App Store Connect: Lumen 1.4 in the
/// scene's phase, moving on as the card's buttons are pressed. The other
/// sample apps are on the App Store.
@MainActor
struct DebugReleaseServices: ReleaseServices {
    var state = DebugReleaseState()
    var error: AppStoreConnectError?
    /// Apple refuses every write, e.g. for a key that may not submit.
    var refusesWrites = false
    /// How long every status read takes after the first, so the Submit
    /// sheet's own read of the builds stays in progress (submit-loading).
    var laterStatusDelay: Duration?
    private let statusReads = DebugReleaseStatusReads()

    func status(for app: StoreApp, platform _: String?) async throws -> ReleaseStatus? {
        if let laterStatusDelay, statusReads.next() > 1 { try await Task.sleep(for: laterStatusDelay) }
        if let error { throw error }
        guard app.id == DebugFixtures.AppID.lumen else { return DebugReleaseData.released(app) }
        return DebugReleaseData.status(state.phase)
    }

    func submit(_ plan: SubmissionPlan) async throws {
        try check()
        state.note(plan)
    }

    func submitEvents(_: [String], for _: StoreApp, platform _: String?) async throws {
        try check()
    }

    func cancelSubmission(_: VersionSubmission.ID) async throws {
        try check()
        state.phase = .prepare
    }

    func resubmit(_: VersionSubmission.ID) async throws {
        try check()
        state.phase = .waiting
    }

    func release(versionID _: String) async throws {
        try check()
        state.phase = .phased
    }

    func setPhasedRelease(_: PhasedRelease.ID, to phased: PhasedRelease.State) async throws {
        try check()
        switch phased {
        case .paused: state.phase = .paused
        case .active: state.phase = .phased
        case .complete: state.phase = .live
        case .inactive: break
        }
    }

    private func check() throws {
        if refusesWrites { throw AppStoreConnectError.forbidden(detail: nil) }
    }
}
#endif
