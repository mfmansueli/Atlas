//
//  SubmissionPlan.swift
//  Atlas
//

import Foundation

/// What Submit for Review sends, in order: the build, its encryption
/// answer, how the version is released, the phased release, and the
/// submission with the version and the In-App Events that go with it.
struct SubmissionPlan: Hashable, Sendable {
    var appID: StoreApp.ID
    var versionID: String
    var platform: String?
    var buildID: String
    /// The build attached now; a different one is attached first.
    var attachedBuildID: String?
    /// The answer to write on the build; nil leaves what it has.
    var usesNonExemptEncryption: Bool?
    var timing: ReleaseTiming
    var isPhased: Bool
    /// The version's phased release, when it has one already.
    var phasedReleaseID: String?
    var eventIDs: [String] = []
    /// A submission made earlier and never sent, to add to.
    var openSubmission: VersionSubmission?
}
