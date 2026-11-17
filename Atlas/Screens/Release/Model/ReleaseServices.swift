//
//  ReleaseServices.swift
//  Atlas
//

import Foundation

/// What submitting and releasing need from App Store Connect.
/// `LiveReleaseServices` talks to it; tests and DEBUG scenes use fakes.
/// Reading is one call; every other call is a write the person asked for
/// with a button.
@MainActor
protocol ReleaseServices {
    /// The version being prepared or on its way (of `platform` when
    /// given, e.g. `IOS`), else the one on the App Store; nil when the app
    /// has no version at all.
    func status(for app: StoreApp, platform: String?) async throws -> ReleaseStatus?
    /// Submits the version for review.
    func submit(_ plan: SubmissionPlan) async throws
    /// Sends In-App Events to App Review on their own.
    func submitEvents(_ eventIDs: [String], for app: StoreApp, platform: String?) async throws
    /// Takes a submission back while it waits for review.
    func cancelSubmission(_ id: VersionSubmission.ID) async throws
    /// Sends a submission App Review returned back to it.
    func resubmit(_ id: VersionSubmission.ID) async throws
    /// Releases an approved version that waits for the person.
    func release(versionID: String) async throws
    /// Pauses, resumes or completes a phased release.
    func setPhasedRelease(_ id: PhasedRelease.ID, to state: PhasedRelease.State) async throws
}
