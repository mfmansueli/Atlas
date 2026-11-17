//
//  ReleaseVersion.swift
//  Atlas
//

import Foundation

/// The version the card follows: the one being prepared or on its way,
/// else the one on the App Store.
struct ReleaseVersion: Identifiable, Hashable, Sendable {
    var id: String
    var versionString: String
    /// `IOS`, `MAC_OS`, …
    var platform: String?
    /// App Store Connect's state, e.g. `PREPARE_FOR_SUBMISSION`.
    var state: String
    var timing: ReleaseTiming
}
