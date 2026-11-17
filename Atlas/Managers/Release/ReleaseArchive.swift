//
//  ReleaseArchive.swift
//  Atlas
//

import Foundation

/// What `ReleaseStore` keeps between launches.
struct ReleaseArchive: Hashable, Codable, Sendable {
    /// Each app's version as last seen.
    var snapshots: [StoreApp.ID: ReleaseSnapshot] = [:]
    /// When Atlas first saw a version in each phase, by version id
    /// then `ReleasePhase.key`: App Store Connect only dates the submission.
    var seen: [String: [String: Date]] = [:]
    /// The In-App Events ticked to go to App Review with each app's version.
    var eventsWithVersion: [StoreApp.ID: [String]] = [:]
}
