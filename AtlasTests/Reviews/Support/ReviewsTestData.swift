//
//  ReviewsTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Reviews for the Reviews tests: a small app with a broken sync in three
/// languages, a price complaint and a happy review. "Now" is Nov 16, 2026.
enum ReviewsTestData {
    static let app = StoreApp(id: "6450000001", name: "Lumen Journal", bundleID: "com.northpier.lumen", sku: "LUMEN-01", primaryLocale: "en-US")
    static let now = Date(timeIntervalSince1970: 1_794_830_400)

    static func review(
        _ id: String, _ territory: String = "US", rating: Int = 1, language: String = "en", version: String? = "1.3", daysAgo: Double = 1,
        reply: ReviewReply? = nil
    ) -> AppReview {
        AppReview(
            id: id, territory: territory, rating: rating, title: "Title \(id)", body: "Body \(id)", nickname: "someone",
            date: now.addingTimeInterval(-daysAgo * 86400), version: version, languageCode: language, reply: reply
        )
    }

    static func reply(_ id: String = "reply-1", text: String = "Thanks!", daysAgo: Double = 0) -> ReviewReply {
        ReviewReply(id: id, text: text, date: now.addingTimeInterval(-daysAgo * 86400))
    }

    static let reviews: [AppReview] = [
        review("de1", "DE", rating: 1, language: "de", daysAgo: 1),
        review("de2", "AT", rating: 2, language: "de", daysAgo: 2),
        review("jp1", "JP", rating: 2, language: "ja", daysAgo: 3),
        review("us1", "US", rating: 1, language: "en", daysAgo: 4),
        review("us2", "US", rating: 5, language: "en", version: "1.2", daysAgo: 20),
        review("fr1", "FR", rating: 4, language: "fr", version: "1.2", daysAgo: 30, reply: reply("reply-fr", text: "Merci !", daysAgo: 29)),
    ]

    static let sync = ReviewTheme(
        id: "sync", title: "iCloud sync since 1.3", note: "Fixed in 1.4.", reviewIDs: ["de1", "de2", "jp1", "us1"], action: .replyToAll,
        replies: [
            ReviewThemeReply(languageCode: "de", text: "Danke. 1.4 repariert das."),
            ReviewThemeReply(languageCode: "en", text: "Thanks. 1.4 fixes it."),
        ],
        source: "Claude Code"
    )

    static func suggestion(_ reviewID: String, text: String = "Danke!") -> ReviewReplySuggestion {
        ReviewReplySuggestion(reviewID: reviewID, text: text, meaning: "Thanks!", source: "Claude Code", date: now)
    }

    /// A store with the reviews read just now, in memory.
    @MainActor
    static func store(reviews: [AppReview] = reviews, next: String? = nil) -> ReviewsStore {
        let store = ReviewsStore()
        store.now = { now }
        store.setFirstPage(ReviewsPage(reviews: reviews, next: next), currentVersion: "1.3", for: app.id)
        return store
    }
}
