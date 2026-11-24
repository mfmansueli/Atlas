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

    struct Paging: Decodable, Sendable {
        var total: Int?
    }

    struct Meta: Decodable, Sendable {
        var paging: Paging?
    }

    var data: [Review]
    var included: [AppStoreConnectResource<CustomerReviewResponseAttributes>]?
    var links: AppStoreConnectPageLinks?
    /// `meta.paging.total`: how many written reviews the app has in all.
    var meta: Meta?

    /// The reply to `review`, from `included`.
    func response(to review: Review) -> AppStoreConnectResource<CustomerReviewResponseAttributes>? {
        guard let id = review.responseID else { return nil }
        return included?.first { $0.id == id }
    }
}
