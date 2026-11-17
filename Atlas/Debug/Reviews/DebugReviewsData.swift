//
//  DebugReviewsData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Canned Ratings & Reviews for Lumen Journal, shaped like the design's
/// board 38: version 1.3 (out Nov 6) broke iCloud sync, so the newest
/// reviews are low, in seven languages; Claude Code suggested a reply for
/// each written-out review and grouped everything into five subjects.
/// "Today" is Nov 16, 2026.
enum DebugReviewsData {
    typealias AppIDs = DebugFixtures.AppID

    static let today = date(month: 11, day: 16)
    static let currentVersion = "1.3"
    static let client = "Claude Code"
    /// Version 1.3 came out on Nov 6.
    static let releaseDay = date(month: 11, day: 6, hour: 0)

    static func date(month: Int, day: Int, hour: Int = 12) -> Date {
        Calendar.gmtGregorian.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .now
    }

    // MARK: - Reviews

    /// The written-out reviews, then the ones made up around them, newest
    /// first.
    static let reviews: [AppReview] = (samples.map(review) + generated).sorted { $0.date > $1.date }

    private static func review(_ sample: DebugReviewSample) -> AppReview {
        AppReview(
            id: sample.id, territory: sample.territory, rating: sample.rating, title: sample.title, body: sample.body,
            nickname: "", date: date(month: 11, day: sample.day), version: currentVersion, languageCode: sample.language,
            reply: sample.isReplied ? ReviewReply(id: "reply-\(sample.id)", text: sample.reply, date: date(month: 11, day: 10)) : nil
        )
    }

    /// Subject, storefront, language, how many, stars, and how many days
    /// before today the first one was written (one more day back every
    /// few reviews).
    private struct Batch {
        var theme: String
        var territory: String
        var language: String
        var count: Int
        var rating: Int
        var back: Int

        /// "sync DE de 13 1 8".
        init?(_ line: Substring) {
            let parts = line.split(separator: " ")
            guard parts.count == 6, let count = Int(parts[3]), let rating = Int(parts[4]), let back = Int(parts[5]) else { return nil }
            (theme, territory, language) = (String(parts[0]), String(parts[1]), String(parts[2]))
            (self.count, self.rating, self.back) = (count, rating, back)
        }
    }

    private static let batches: [Batch] = """
    sync DE de 13 1 8
    sync JP ja 10 1 8
    sync US en 6 2 8
    sync FR fr 3 1 9
    sync NL nl 2 2 9
    sync IT it 1 1 10
    sync SE sv 1 2 10
    price JP ja 8 2 12
    price BR pt 6 2 13
    price KR ko 3 2 14
    price MX es 1 3 15
    price ES es 1 2 16
    price IT it 1 2 17
    remind FR fr 3 2 12
    remind US en 3 2 13
    remind IT it 2 2 14
    widget BR pt 2 4 15
    widget US en 2 4 18
    widget DE de 2 4 20
    love US en 20 5 12
    love GB en 10 5 14
    love DE de 8 5 16
    love JP ja 8 5 18
    love FR fr 6 5 20
    love KR ko 4 5 22
    love BR pt 6 5 24
    export US en 3 4 30
    export DE de 3 3 34
    """.split(separator: "\n").compactMap(Batch.init)

    private static let generated: [AppReview] = batches.flatMap { batch in
        (0..<batch.count).map { index in
            let text = texts[batch.theme]?[batch.language] ?? ["", ""]
            // Sync reviews all come after 1.3; the others spread out.
            let spread = batch.theme == "sync" ? index / 12 : index / 2
            let written = today.addingTimeInterval(-Double(batch.back + spread) * 86400 - Double(index) * 600)
            let id = "g-\(batch.theme)-\(batch.territory.lowercased())-\(index + 1)"
            return AppReview(
                id: id, territory: batch.territory, rating: batch.rating, title: text[0], body: text[1], nickname: "", date: written,
                version: written >= releaseDay ? currentVersion : "1.2", languageCode: batch.language,
                // The older requests for an export were answered at the time.
                reply: batch.theme == "export" ? ReviewReply(id: "reply-\(id)", text: "Thanks! PDF export is coming in 1.5.", date: written.addingTimeInterval(86400)) : nil
            )
        }
    }

    /// Every review not in English, in English.
    static let translations: [AppReview.ID: ReviewTranslation] = {
        var translations: [AppReview.ID: ReviewTranslation] = [:]
        for sample in samples where !sample.titleEN.isEmpty {
            translations[sample.id] = ReviewTranslation(title: sample.titleEN, body: sample.bodyEN)
        }
        for review in generated {
            let theme = review.id.split(separator: "-").dropFirst().first.map(String.init) ?? ""
            guard let text = texts[theme]?[review.languageCode], text.count == 4 else { continue }
            translations[review.id] = ReviewTranslation(title: text[2], body: text[3])
        }
        return translations
    }()

    /// A reply for each written-out review that has none on the App Store.
    static let suggestions: [AppReview.ID: ReviewReplySuggestion] = Dictionary(
        uniqueKeysWithValues: samples.filter { !$0.isReplied }.map { sample in
            (sample.id, ReviewReplySuggestion(reviewID: sample.id, text: sample.reply, meaning: sample.replyEN, source: client, date: today))
        }
    )

    // MARK: - Groups

    private static func ids(_ theme: String, _ written: [String]) -> [AppReview.ID] {
        written + generated.map(\.id).filter { $0.hasPrefix("g-\(theme)-") }
    }

    static let themes: [ReviewTheme] = [
        ReviewTheme(
            id: "sync", title: "iCloud sync since 1.3", note: "Fixed in 1.4. Replies can say so, in each reviewer’s language.",
            reviewIDs: ids("sync", ["r-de1", "r-jp2"]), action: .replyToAll, replies: syncReplies, source: client
        ),
        ReviewTheme(
            id: "price", title: "The price feels high",
            note: "Most of them think there’s only a yearly plan. The Monthly plan isn’t on the Japanese page.",
            reviewIDs: ids("price", ["r-jp1"]), action: .openPricing(territory: "JP"), source: client
        ),
        ReviewTheme(
            id: "remind", title: "Evening reminder stopped", note: "Since iOS 26.1. The fix is in the phone’s settings.",
            reviewIDs: ids("remind", ["r-fr1"]), action: .replyToAll, replies: reminderReplies, source: client
        ),
        ReviewTheme(
            id: "widget", title: "A dark widget", note: "A feature request, mostly from 4-star reviews.",
            reviewIDs: ids("widget", ["r-br1"]), action: .showReviews, source: client
        ),
        ReviewTheme(
            id: "love", title: "What people love", note: "No ads, the design, the prompts: words worth reusing on the store page.",
            reviewIDs: ids("love", ["r-us1", "r-kr1"]), action: .suggestStorePage, source: client
        ),
    ]

    // MARK: - Ratings

    /// Apple's average and count per storefront: 12,840 ratings, 4.6.
    private static let storefronts: [(country: String, average: Double, count: Int)] = [
        ("US", 4.7, 5200), ("DE", 4.4, 1900), ("JP", 4.5, 1500), ("GB", 4.7, 1100), ("FR", 4.6, 820), ("BR", 4.6, 700),
        ("KR", 4.7, 420), ("IT", 4.5, 360), ("NL", 4.6, 300), ("ES", 4.6, 240), ("SE", 4.5, 180), ("MX", 4.6, 120),
    ]

    static func ratings(in countries: Set<String>) -> StoreRatings {
        var ratings = StoreRatings.unchecked
        for storefront in storefronts where countries.contains(storefront.country) {
            ratings.record(.rated(storefront.average), count: storefront.count, inCountry: storefront.country)
        }
        return ratings
    }

    // MARK: - Store

    static var archive: ReviewsArchive {
        ReviewsArchive(
            reviews: reviews, fetchedAt: today, currentVersion: currentVersion, suggestions: suggestions, themes: themes, translations: translations
        )
    }

    /// Lumen's reviews as just read; the other apps have none yet.
    @MainActor
    static func store(archive: ReviewsArchive = DebugReviewsData.archive) -> ReviewsStore {
        let store = ReviewsStore()
        store.now = { today }
        store.load(archive, for: AppIDs.lumen)
        return store
    }
}
#endif
