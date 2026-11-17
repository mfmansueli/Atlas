//
//  CustomerReviewResponseAttributes.swift
//  Atlas
//

import Foundation

/// A `customerReviewResponses` resource: the developer's reply to a review.
struct CustomerReviewResponseAttributes: Decodable, Sendable {
    var responseBody: String?
    var lastModifiedDate: String?
    /// `PUBLISHED` or `PENDING_PUBLISH`.
    var state: String?

    static let pendingState = "PENDING_PUBLISH"
}
