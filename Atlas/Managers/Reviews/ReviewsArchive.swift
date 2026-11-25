//
//  ReviewsArchive.swift
//  Atlas
//

import Foundation

/// What this Mac keeps about one app's reviews: the reviews read from App
/// Store Connect, the replies and groups an assistant suggested, and the
/// translations already made.
struct ReviewsArchive: Hashable, Codable, Sendable {
    /// Newest first, as Apple lists them.
    var reviews: [AppReview] = []
    /// Apple's link to the reviews after these; nil at the end.
    var next: String?
    /// Apple's count of the app's written reviews, read or not.
    var writtenTotal: Int?
    var fetchedAt: Date?
    /// The version the newest reviews are listed under ("1.3").
    var currentVersion: String?
    var suggestions: [AppReview.ID: ReviewReplySuggestion] = [:]
    /// Reviews whose suggested reply was dismissed.
    var dismissed: Set<AppReview.ID> = []
    var themes: [ReviewTheme] = []
    var translations: [AppReview.ID: ReviewTranslation] = [:]

    /// How many written reviews the app has: Apple's count, or the ones
    /// read when they're all here; nil when neither is known.
    var writtenCount: Int? {
        if let writtenTotal { return max(writtenTotal, reviews.count) }
        return fetchedAt != nil && next == nil ? reviews.count : nil
    }

    func review(id: AppReview.ID) -> AppReview? {
        reviews.first { $0.id == id }
    }

    /// The suggested reply a review still shows: it has no reply yet and
    /// the suggestion wasn't dismissed.
    func openSuggestion(for review: AppReview) -> ReviewReplySuggestion? {
        guard !review.hasReply, !dismissed.contains(review.id), suggestions[review.id]?.isReplacement != true else { return nil }
        return suggestions[review.id]
    }

    /// A new text suggested for the reply a review already has: shown under
    /// that reply until it's sent, dismissed, or the reply changes. Never
    /// sent by Reply Automatically.
    func openReplacement(for review: AppReview) -> ReviewReplySuggestion? {
        guard let reply = review.reply, !dismissed.contains(review.id), let suggestion = suggestions[review.id],
              let replaced = suggestion.replaces, replaced.text == reply.text, suggestion.text != reply.text else { return nil }
        return suggestion
    }

    /// Replacements waiting for the person.
    var openReplacementCount: Int {
        reviews.count { openReplacement(for: $0) != nil }
    }

    /// Suggested replies waiting for the person: the section's count.
    var openSuggestionCount: Int {
        reviews.count { openSuggestion(for: $0) != nil && $0.needsReply }
    }

    var needsReplyCount: Int {
        reviews.count(where: \.needsReply)
    }

    /// The languages the reviews that need a reply are written in.
    var needsReplyLanguageCount: Int {
        Set(reviews.filter(\.needsReply).map { ReviewTheme.base($0.languageCode) }.filter { !$0.isEmpty }).count
    }

    /// Drops what refers to reviews that are gone.
    mutating func prune() {
        let ids = Set(reviews.map(\.id))
        suggestions = suggestions.filter { ids.contains($0.key) }
        dismissed.formIntersection(ids)
        translations = translations.filter { ids.contains($0.key) }
    }
}
