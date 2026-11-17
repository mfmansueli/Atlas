//
//  DebugReviewsServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Reviews without App Store Connect: scenes load the sample reviews into
/// the store, so reading brings them back, and a reply "sent" here goes
/// nowhere. Optionally failing, never finishing, or refusing replies.
@MainActor
struct DebugReviewsServices: ReviewsServices {
    var error: AppStoreConnectError?
    /// A read that never ends, for the loading scene.
    var neverFinishes = false
    /// Apple refuses every reply, as it does for a key that may not write.
    var refusesReplies = false
    var translator: any ReviewTranslator = DebugReviewTranslator()

    func reviews(for app: StoreApp, after _: String?) async throws -> ReviewsPage {
        if neverFinishes { try await Task.sleep(for: .seconds(3600)) }
        if let error { throw error }
        return ReviewsPage(reviews: app.id == DebugFixtures.AppID.lumen ? DebugReviewsData.reviews : [], next: nil)
    }

    func currentVersion(for app: StoreApp) async throws -> String? {
        app.id == DebugFixtures.AppID.lumen ? DebugReviewsData.currentVersion : nil
    }

    func sendReply(_ text: String, to reviewID: AppReview.ID) async throws -> ReviewReply {
        if refusesReplies { throw AppStoreConnectError.forbidden(detail: nil) }
        return ReviewReply(id: "debug-reply-\(reviewID)", text: text, date: DebugReviewsData.today)
    }

    func deleteReply(_: ReviewReply.ID) async throws {}

    func ratings(for app: StoreApp, countries: Set<String>) async -> StoreRatings {
        guard app.id == DebugFixtures.AppID.lumen else { return .unchecked }
        return DebugReviewsData.ratings(in: countries)
    }
}
#endif
