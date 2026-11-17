//
//  CustomerReviewsDocument.swift
//  Atlas
//

import Foundation

/// A page of `customerReviews` with each review's reply included
/// (`include=response`).
struct CustomerReviewsDocument: Decodable, Sendable {
    struct Review: Decodable, Sendable {
        var id: String
        var attributes: CustomerReviewAttributes
        var relationships: [String: AppInformationLinkage]?

        /// The id of its reply, when it has one.
        var responseID: String? { relationships?["response"]?.data?.id }
    }

    var data: [Review]
    var included: [AppStoreConnectResource<CustomerReviewResponseAttributes>]?
    var links: AppStoreConnectPageLinks?

    /// The reply to `review`, from `included`.
    func response(to review: Review) -> AppStoreConnectResource<CustomerReviewResponseAttributes>? {
        guard let id = review.responseID else { return nil }
        return included?.first { $0.id == id }
    }
}
