//
//  SubmissionPlan.swift
//  Atlas
//

import Foundation

/// What Submit for Review sends, in order: the build, its encryption
/// answer, how the version is released, the phased release, and the
/// submission with the version, the In-App Events that go with it and the
/// subscriptions and in-app purchases submitted with it.
/// The phased release and an open submission are read from App Store
/// Connect while submitting, not carried here: an attempt that stopped
/// halfway may have made them.
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
    var eventIDs: [String] = []
    /// Ready to Submit products that go with the version: each is
    /// submitted before the review submission is sent.
    var products: [SubmissionProduct] = []
}
