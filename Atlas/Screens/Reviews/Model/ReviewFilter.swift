//
//  ReviewFilter.swift
//  Atlas
//

import Foundation

/// What the review list shows.
enum ReviewFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case needsReply
    case lowStars
    case replied
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needsReply: String(localized: "Needs a Reply")
        case .lowStars: String(localized: "1–2 Stars")
        case .replied: String(localized: "Replied")
        case .all: String(localized: "All")
        }
    }

    func includes(_ review: AppReview) -> Bool {
        switch self {
        case .needsReply: review.needsReply
        case .lowStars: review.isLow
        case .replied: review.hasReply
        case .all: true
        }
    }
}
