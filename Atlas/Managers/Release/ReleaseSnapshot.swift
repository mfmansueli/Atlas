//
//  ReleaseSnapshot.swift
//  Atlas
//

import Foundation

/// The last thing Atlas saw of an app's version, kept so the
/// sidebar's footer has something to say before App Store Connect answers
/// and so versions on their way are checked on.
struct ReleaseSnapshot: Hashable, Codable, Sendable {
    var versionID: String
    var versionString: String
    var platform: String?
    /// `ReleasePhase.key`.
    var phaseKey: String
    /// Phased release: the day, and whether it's paused.
    var day = 0
    var isPaused = false

    init(_ status: ReleaseStatus) {
        versionID = status.version.id
        versionString = status.version.versionString
        platform = status.version.platform
        phaseKey = status.phase.key
        if case let .phased(day, isPaused) = status.phase {
            self.day = day
            self.isPaused = isPaused
        }
    }

    var phase: ReleasePhase {
        switch phaseKey {
        case "waiting": .waitingForReview
        case "review": .inReview
        case "rejected": .rejected
        case "pending": .pendingDeveloperRelease
        case "approved": .pendingAppleRelease
        case "phased": .phased(day: max(day, 1), isPaused: isPaused)
        case "live": .live
        default: .prepare
        }
    }
}
