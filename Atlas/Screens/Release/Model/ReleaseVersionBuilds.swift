//
//  ReleaseVersionBuilds.swift
//  Atlas
//

import Foundation

/// The builds uploaded for one App Store version (its number, on its
/// platform), newest first, and the one attached to it, as the Submit sheet
/// reads them.
struct ReleaseVersionBuilds: Hashable, Sendable {
    var builds: [ReleaseBuild] = []
    /// The build App Store Connect has attached to the version.
    var attachedBuildID: String?
    /// Its number, read with the attachment: the attached build may be
    /// older than the ones listed.
    var attachedBuildNumber: String?

    var attached: ReleaseBuild? {
        builds.first { $0.id == attachedBuildID }
    }
}
