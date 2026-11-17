//
//  ReviewSort.swift
//  Atlas
//

import Foundation

/// The review list's order.
enum ReviewSort: String, CaseIterable, Identifiable, Hashable, Sendable {
    case newest
    case oldest
    case lowestRating
    case highestRating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: String(localized: "Newest")
        case .oldest: String(localized: "Oldest")
        case .lowestRating: String(localized: "Lowest Rating")
        case .highestRating: String(localized: "Highest Rating")
        }
    }

    /// Ties go to the newer review.
    func sorted(_ reviews: [AppReview]) -> [AppReview] {
        reviews.sorted { lhs, rhs in
            switch self {
            case .newest: lhs.date > rhs.date
            case .oldest: lhs.date < rhs.date
            case .lowestRating: lhs.rating == rhs.rating ? lhs.date > rhs.date : lhs.rating < rhs.rating
            case .highestRating: lhs.rating == rhs.rating ? lhs.date > rhs.date : lhs.rating > rhs.rating
            }
        }
    }
}
