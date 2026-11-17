//
//  FakeReviewsServices.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Reviews without App Store Connect: canned pages, and replies that are
/// recorded instead of sent.
@MainActor
final class FakeReviewsServices: ReviewsServices {
    var pages: [String?: ReviewsPage] = [:]
    var currentVersion: String? = "1.3"
    var readError: AppStoreConnectError?
    /// Reviews Apple refuses a reply to.
    var refused: Set<AppReview.ID> = []
    var storeRatings = StoreRatings.unchecked
    var translator: any ReviewTranslator = FakeReviewTranslator()

    private(set) var readCursors: [String?] = []
    private(set) var sent: [(reviewID: AppReview.ID, text: String)] = []
    private(set) var deleted: [ReviewReply.ID] = []
    private(set) var ratingCountries: Set<String> = []

    init(reviews: [AppReview] = ReviewsTestData.reviews, next: String? = nil) {
        pages[nil] = ReviewsPage(reviews: reviews, next: next)
    }

    func reviews(for _: StoreApp, after cursor: String?) async throws -> ReviewsPage {
        readCursors.append(cursor)
        if let readError { throw readError }
        return pages[cursor] ?? ReviewsPage(reviews: [], next: nil)
    }

    func currentVersion(for _: StoreApp) async throws -> String? { currentVersion }

    func sendReply(_ text: String, to reviewID: AppReview.ID) async throws -> ReviewReply {
        if refused.contains(reviewID) { throw AppStoreConnectError.forbidden(detail: nil) }
        sent.append((reviewID, text))
        return ReviewReply(id: "sent-\(sent.count)", text: text, date: ReviewsTestData.now, isPending: true)
    }

    func deleteReply(_ replyID: ReviewReply.ID) async throws {
        deleted.append(replyID)
    }

    func ratings(for _: StoreApp, countries: Set<String>) async -> StoreRatings {
        ratingCountries = countries
        return storeRatings
    }
}
