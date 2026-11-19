//
//  ProductPageState.swift
//  Atlas
//

import Foundation

/// Where a custom product page's version is with App Review, from
/// `appCustomProductPageVersions.state`. The page itself has no state: each
/// version has one, and a page approved once keeps showing while its next
/// version is reviewed.
enum ProductPageState: String, Codable, Hashable, Sendable, CaseIterable {
    case prepareForSubmission = "PREPARE_FOR_SUBMISSION"
    case readyForReview = "READY_FOR_REVIEW"
    case waitingForReview = "WAITING_FOR_REVIEW"
    case inReview = "IN_REVIEW"
    case accepted = "ACCEPTED"
    case approved = "APPROVED"
    case replacedWithNewVersion = "REPLACED_WITH_NEW_VERSION"
    case rejected = "REJECTED"

    /// The pill: "Prepare for Submission", "Waiting for Review", "In Review",
    /// "Approved", "Rejected".
    var title: String {
        switch self {
        case .prepareForSubmission, .readyForReview: String(localized: "Prepare for Submission")
        case .waitingForReview: String(localized: "Waiting for Review")
        case .inReview: String(localized: "In Review")
        case .accepted, .approved, .replacedWithNewVersion: String(localized: "Approved")
        case .rejected: String(localized: "Rejected")
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .prepareForSubmission, .readyForReview: .neutral
        case .waitingForReview, .inReview: .warning
        case .accepted, .approved, .replacedWithNewVersion: .decrease
        case .rejected: .danger
        }
    }

    /// Its texts, keywords and deep link can be changed.
    var isEditable: Bool {
        switch self {
        case .prepareForSubmission, .readyForReview, .rejected: true
        case .waitingForReview, .inReview, .accepted, .approved, .replacedWithNewVersion: false
        }
    }

    /// With App Review: nothing on the page can change until it's back.
    var isLocked: Bool { self == .waitingForReview || self == .inReview }

    /// Apple approved it: it can be visible on the App Store.
    var isApproved: Bool { self == .approved || self == .accepted }
}
