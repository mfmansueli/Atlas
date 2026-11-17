//
//  ReviewsPage.swift
//  Atlas
//

import Foundation

/// One read of an app's reviews, newest first, and where the next ones are.
struct ReviewsPage: Hashable, Sendable {
    var reviews: [AppReview]
    /// Apple's link to the reviews after these; nil at the end.
    var next: String?
}
