//
//  ReviewsEmptyText.swift
//  Atlas
//

import Foundation

/// What the review list says when what's chosen shows nothing (board 74 ·
/// 8): the smaller empty state where the reviews would be, with Show All
/// Reviews whenever a filter, a group or a country hides the others.
struct ReviewsEmptyText: Equatable {
    let title: String
    let text: String
    let showsAllReviews: Bool

    static func make(filter: ReviewFilter, hasTheme: Bool, hasTerritory: Bool) -> ReviewsEmptyText {
        let showsAll = filter != .all || hasTheme || hasTerritory
        if hasTheme {
            return ReviewsEmptyText(
                title: String(localized: "No reviews about this", comment: "kind:empty-state"),
                text: String(localized: "Reviews about it show up here.", comment: "kind:description"),
                showsAllReviews: showsAll
            )
        }
        if hasTerritory, filter == .all {
            return ReviewsEmptyText(
                title: String(localized: "No reviews in this country", comment: "kind:empty-state"),
                text: String(localized: "Reviews people write there show up here.", comment: "kind:description"),
                showsAllReviews: showsAll
            )
        }
        let (title, text) = switch filter {
        case .needsReply:
            (String(localized: "Every review has a reply", comment: "kind:empty-state"),
             String(localized: "New reviews that need one show up here.", comment: "kind:description"))
        case .lowStars:
            (String(localized: "No 1 or 2 star reviews", comment: "kind:empty-state"),
             String(localized: "Reviews with 1 or 2 stars show up here.", comment: "kind:description"))
        case .replied:
            (String(localized: "No replies yet", comment: "kind:empty-state"),
             String(localized: "Replies you send show up here.", comment: "kind:description"))
        case .all:
            (String(localized: "No reviews yet", comment: "kind:empty-state"),
             String(localized: "Reviews from every country show up here.", comment: "kind:description"))
        }
        return ReviewsEmptyText(title: title, text: text, showsAllReviews: showsAll)
    }
}
