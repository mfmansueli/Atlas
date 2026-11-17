//
//  ReviewsServices.swift
//  Atlas
//

import Foundation

/// What Reviews needs from outside itself. `LiveReviewsServices` talks to
/// App Store Connect, the App Store's lookup and Apple Translation; tests
/// and DEBUG scenes use canned data.
@MainActor
protocol ReviewsServices {
    /// The newest reviews with their replies, or the page after `cursor`
    /// (an earlier page's `next`).
    func reviews(for app: StoreApp, after cursor: String?) async throws -> ReviewsPage
    /// The version the newest reviews are about ("1.3"); nil when the app
    /// has none on the App Store.
    func currentVersion(for app: StoreApp) async throws -> String?
    /// Replies to a review in public, replacing the reply it has.
    func sendReply(_ text: String, to reviewID: AppReview.ID) async throws -> ReviewReply
    /// Takes a reply off the App Store.
    func deleteReply(_ replyID: ReviewReply.ID) async throws
    /// Apple's average rating and count in each of `countries` (alpha-2).
    func ratings(for app: StoreApp, countries: Set<String>) async -> StoreRatings
    var translator: any ReviewTranslator { get }
}
