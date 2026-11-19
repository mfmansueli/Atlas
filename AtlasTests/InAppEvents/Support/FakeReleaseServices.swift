//
//  FakeReleaseServices.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Submitting without App Store Connect: what was asked is recorded.
@MainActor
final class FakeReleaseServices: ReleaseServices {
    var status: ReleaseStatus?
    var refuses = false
    private(set) var submittedEvents: [[String]] = []
    private(set) var plans: [SubmissionPlan] = []
    private(set) var actions: [String] = []

    func status(for _: StoreApp, platform _: String?) async throws -> ReleaseStatus? { status }

    func submit(_ plan: SubmissionPlan) async throws {
        try check()
        plans.append(plan)
    }

    func submitEvents(_ eventIDs: [String], for _: StoreApp, platform _: String?) async throws {
        try check()
        submittedEvents.append(eventIDs)
    }

    func cancelSubmission(_ id: VersionSubmission.ID) async throws {
        try check()
        actions.append("cancel \(id)")
    }

    func resubmit(_ id: VersionSubmission.ID) async throws {
        try check()
        actions.append("resubmit \(id)")
    }

    func release(versionID: String) async throws {
        try check()
        actions.append("release \(versionID)")
    }

    func setPhasedRelease(_ id: PhasedRelease.ID, to state: PhasedRelease.State) async throws {
        try check()
        actions.append("phased \(id) \(state.rawValue)")
    }

    /// Each version's builds, by version id.
    var versionBuilds: [String: ReleaseVersionBuilds] = [:]
    /// Versions whose builds can't be read.
    var failingBuilds: Set<String> = []

    func builds(for _: StoreApp, versionID: String, versionString _: String, platform _: String?) async throws -> ReleaseVersionBuilds {
        if failingBuilds.contains(versionID) { throw AppStoreConnectError.forbidden(detail: nil) }
        return versionBuilds[versionID] ?? ReleaseVersionBuilds()
    }

    private func check() throws {
        if refuses { throw AppStoreConnectError.forbidden(detail: nil) }
    }
}
