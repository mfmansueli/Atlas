//
//  ReleasePhase.swift
//  Atlas
//

import Foundation

/// Where a version is on its way to the App Store, as the Overview's
/// version card and the sidebar's footer follow it.
enum ReleasePhase: Hashable, Sendable {
    /// Not submitted yet, or back from a canceled submission.
    case prepare
    case waitingForReview
    case inReview
    /// App Review sent it back.
    case rejected
    /// Approved; the person chose to release it themselves.
    case pendingDeveloperRelease
    /// Approved; Apple releases it (right away, or on the chosen date).
    case pendingAppleRelease
    /// On the App Store, reaching automatic updates over 7 days.
    case phased(day: Int, isPaused: Bool)
    /// On the App Store for everyone.
    case live

    /// The phase App Store Connect's version state and phased release say.
    init(state: String, phased: PhasedRelease?) {
        switch state {
        case "WAITING_FOR_REVIEW": self = .waitingForReview
        case "IN_REVIEW": self = .inReview
        case "REJECTED", "METADATA_REJECTED", "INVALID_BINARY": self = .rejected
        case "PENDING_DEVELOPER_RELEASE": self = .pendingDeveloperRelease
        case "PENDING_APPLE_RELEASE", "PROCESSING_FOR_DISTRIBUTION", "PROCESSING_FOR_APP_STORE", "ACCEPTED": self = .pendingAppleRelease
        case "READY_FOR_DISTRIBUTION", "READY_FOR_SALE":
            if let phased, phased.isRollingOut {
                self = .phased(day: max(phased.day, 1), isPaused: phased.state == .paused)
            } else {
                self = .live
            }
        default: self = .prepare
        }
    }

    /// A stable name, for what's kept on this Mac.
    var key: String {
        switch self {
        case .prepare: "prepare"
        case .waitingForReview: "waiting"
        case .inReview: "review"
        case .rejected: "rejected"
        case .pendingDeveloperRelease: "pending"
        case .pendingAppleRelease: "approved"
        case .phased: "phased"
        case .live: "live"
        }
    }

    /// Submitted and not yet out for everyone: worth checking on.
    var isInFlight: Bool {
        switch self {
        case .waitingForReview, .inReview, .pendingDeveloperRelease, .pendingAppleRelease, .phased: true
        case .prepare, .rejected, .live: false
        }
    }

    /// App Store Connect's own name for it, on the card's pill.
    var pillTitle: String {
        switch self {
        case .prepare: String(localized: "Prepare for Submission")
        case .waitingForReview: String(localized: "Waiting for Review")
        case .inReview: String(localized: "In Review")
        case .rejected: String(localized: "Rejected")
        case .pendingDeveloperRelease: String(localized: "Pending Developer Release")
        case .pendingAppleRelease: String(localized: "Pending Apple Release")
        case let .phased(day, isPaused): Self.phasedTitle(day: day, isPaused: isPaused)
        case .live: String(localized: "Ready for Distribution")
        }
    }

    private static func phasedTitle(day: Int, isPaused: Bool) -> String {
        if isPaused { return String(localized: "Phased Release Paused") }
        return String(localized: "Phased Release · Day \(day) of \(PhasedRelease.dayCount)")
    }
}
