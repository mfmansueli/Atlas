//
//  WatchSignalKind.swift
//  Atlas
//

import Foundation

/// What Look for Improvements' own checks look for in an app, in the order
/// the person needs them: what blocks App Review first, then what costs
/// money, then reach. Each one comes from data Atlas already read in its
/// hourly check, so finding them asks App Store Connect for nothing more.
enum WatchSignalKind: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// The version in Prepare for Submission can't be submitted yet: Export
    /// Compliance, App Compliance, the age rating or App Review's contact.
    case submissionBlocked
    /// App Review sent the version back.
    case versionRejected
    /// Atlas's App Review checks (`ReviewRiskEngine`) found risks an
    /// assistant can fix with a proposal, or project checks only the code
    /// answers (account deletion, Sign in with Apple, permission texts).
    case appReviewRisk
    /// An In-App Event whose card shows within a week still misses what App
    /// Review or its languages need.
    case eventDeadline
    /// What's New is empty in some languages of the version being prepared,
    /// while the project has commits since the last release.
    case whatsNewMissing
    /// The newest version crashes clearly more than the one before.
    case crashesWorse
    /// Reviews since a release: a rating drop or many 1–2 stars nobody grouped.
    case reviewsAfterRelease

    var id: String { rawValue }

    /// Said by Atlas alone, never sent to an assistant for now: what App
    /// Review said and the answers only the person can give.
    var isLocalOnly: Bool {
        switch self {
        case .submissionBlocked, .versionRejected: true
        case .appReviewRisk, .eventDeadline, .whatsNewMissing, .crashesWorse, .reviewsAfterRelease: false
        }
    }

    /// The shortest time between two runs that bring it up for the same app,
    /// before backoff (`WatchBackoff`) stretches it.
    var baseInterval: TimeInterval { 24 * 3600 }
}
