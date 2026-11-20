//
//  InAppEventState.swift
//  Atlas
//

import Foundation

/// Where App Store Connect says an In-App Event is.
enum InAppEventState: String, Hashable, Sendable {
    case draft = "DRAFT"
    case readyForReview = "READY_FOR_REVIEW"
    case waitingForReview = "WAITING_FOR_REVIEW"
    case inReview = "IN_REVIEW"
    case rejected = "REJECTED"
    case accepted = "ACCEPTED"
    case approved = "APPROVED"
    case published = "PUBLISHED"
    case past = "PAST"
    case archived = "ARCHIVED"

    /// An unknown state reads as a draft: nothing is assumed live.
    init(apiValue: String?) {
        self = apiValue.flatMap(InAppEventState.init(rawValue:)) ?? .draft
    }

    /// Its texts can still be changed without a new review.
    var isEditable: Bool {
        switch self {
        case .draft, .readyForReview, .rejected: true
        case .waitingForReview, .inReview, .accepted, .approved, .published, .past, .archived: false
        }
    }

    /// With App Review, or through it and not over yet.
    var isSubmitted: Bool {
        switch self {
        case .waitingForReview, .inReview, .accepted, .approved, .published: true
        case .draft, .readyForReview, .rejected, .past, .archived: false
        }
    }

    var isOver: Bool { self == .past || self == .archived }

    /// Not approved yet: its dates still have to be ahead when App Review
    /// takes it.
    var isBeforeApproval: Bool {
        switch self {
        case .draft, .readyForReview, .waitingForReview, .inReview, .rejected: true
        case .accepted, .approved, .published, .past, .archived: false
        }
    }
}
