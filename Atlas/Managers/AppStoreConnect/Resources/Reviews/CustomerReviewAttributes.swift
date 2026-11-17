//
//  CustomerReviewAttributes.swift
//  Atlas
//

import Foundation

/// A `customerReviews` resource: what someone wrote on the App Store.
struct CustomerReviewAttributes: Decodable, Sendable {
    var rating: Int?
    var title: String?
    var body: String?
    var territory: String?
    var reviewerNickname: String?
    /// ISO 8601, e.g. `2026-11-15T10:42:00-08:00`.
    var createdDate: String?
}
