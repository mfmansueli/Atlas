//
//  ReviewThemeSummary.swift
//  Atlas
//

import Foundation

/// A group of reviews as its card shows it: how many, where they come
/// from, whether they're mostly 1 and 2 stars, and its button.
struct ReviewThemeSummary: Identifiable, Hashable, Sendable {
    var theme: ReviewTheme
    /// The group's reviews that are on this Mac.
    var count: Int
    /// "Germany 14 · Japan 11 · U.S. 6 · 4 more".
    var whereText: String
    /// At least half are 1 or 2 stars.
    var isMostlyLow: Bool
    /// Reviews without a reply that Reply to All has a message for.
    var replyCount: Int

    var id: String { theme.id }

    /// How many storefronts the "where" line names before "n more".
    static let namedTerritories = 3

    static func make(_ theme: ReviewTheme, reviews: [AppReview]) -> ReviewThemeSummary {
        let ids = Set(theme.reviewIDs)
        let found = reviews.filter { ids.contains($0.id) }
        let low = found.count(where: \.isLow)
        return ReviewThemeSummary(
            theme: theme,
            count: found.count,
            whereText: whereText(found),
            isMostlyLow: !found.isEmpty && low * 2 >= found.count,
            replyCount: ReviewBulkPlan.make(theme, reviews: reviews).replyCount
        )
    }

    /// "38 reviews"; what people love counts mentions.
    var countText: String {
        guard theme.action == .suggestStorePage else { return ReviewText.reviews(count) }
        return count == 1 ? String(localized: "1 mention") : String(localized: "\(ReviewText.count(count)) mentions")
    }

    var buttonTitle: String {
        switch theme.action {
        case .replyToAll:
            return String(localized: "Reply to All \(replyCount)…")
        case let .openPricing(territory):
            guard let territory, let name = TerritoryCatalog.standard.territory(alpha2: territory)?.name else { return String(localized: "Open Pricing") }
            return String(localized: "Open Pricing for \(name)")
        case .showReviews:
            return String(localized: "Show Reviews")
        case .suggestStorePage:
            return String(localized: "Suggest for Store Page")
        }
    }

    /// Reply to All with nobody left to reply to has nothing to do.
    var isButtonEnabled: Bool {
        theme.action != .replyToAll || replyCount > 0
    }

    private static func whereText(_ reviews: [AppReview]) -> String {
        let counts = Dictionary(grouping: reviews.filter { !$0.territory.isEmpty }, by: \.territory).mapValues(\.count)
        let ranked = counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        var parts = ranked.prefix(namedTerritories).map { "\(ReviewText.shortTerritory($0.key)) \($0.value)" }
        let rest = ranked.count - parts.count
        if rest > 0 { parts.append(String(localized: "\(rest) more")) }
        return parts.joined(separator: " · ")
    }
}
