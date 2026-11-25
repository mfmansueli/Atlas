//
//  ReleaseStatus.swift
//  Atlas
//

import Foundation

/// Everything read about the version for the card and the Submit sheet.
struct ReleaseStatus: Hashable, Sendable {
    var version: ReleaseVersion
    /// The builds uploaded for this version, newest first.
    var builds: [ReleaseBuild] = []
    /// The build App Store Connect has attached to the version.
    var attachedBuildID: String?
    var phased: PhasedRelease?
    /// The submission the version is in, or an open one to add it to.
    var submission: VersionSubmission?
    /// App Review's contact (and the demo account, when sign-in is needed)
    /// are filled in.
    var isReviewInformationComplete = true
    /// Subscriptions and in-app purchases Ready to Submit, which can go to
    /// App Review with the version (read before submitting).
    var productsToSubmit: [SubmissionProduct] = []

    var phase: ReleasePhase {
        ReleasePhase(state: version.state, phased: phased)
    }

    var attachedBuild: ReleaseBuild? {
        builds.first { $0.id == attachedBuildID }
    }
}
