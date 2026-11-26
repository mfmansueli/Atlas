//
//  OverviewRating.swift
//  Atlas
//

import Foundation

/// The Overview's Rating number: the App Store's average (as Ratings &
/// Reviews reads it), and the written reviews of the current version and
/// the one before it, "3.9 ★ on 1.4 · 4.7 ★ on 1.3".
struct OverviewRating: Hashable, Sendable {
    /// The App Store's average; nil before any storefront has a rating.
    var average: Double?
    var version: String?
    var versionAverage: Double?
    var previousVersion: String?
    var previousAverage: Double?
    /// The current version's reviews are surely lower than the ones before.
    var isLower = false

    static func make(average: Double?, reviews: [AppReview], currentVersion: String?) -> OverviewRating {
        var rating = OverviewRating(average: average)
        guard let version = currentVersion else { return rating }
        let current = reviews.filter { $0.version == version }
        guard let versionAverage = StarHistogram(current).average else { return rating }
        rating.version = version
        rating.versionAverage = versionAverage
        let earlier = Set(reviews.compactMap(\.version)).filter { AppVersionOrder.isBefore($0, version) }
        if let previous = earlier.max(by: AppVersionOrder.isBefore),
           let previousAverage = StarHistogram(reviews.filter { $0.version == previous }).average
        {
            rating.previousVersion = previous
            rating.previousAverage = previousAverage
        }
        let before = reviews.filter { $0.version != version }.map(\.rating)
        rating.isLower = VersionRatingComparison.outcome(current.map(\.rating), against: before).isLower
        return rating
    }

    /// "3.9 ★ on 1.4 · 4.7 ★ on 1.3", or nil without reviews of the
    /// current version.
    var versionsText: String? {
        guard let version, let versionAverage else { return nil }
        let current = String(localized: "\(RatingsSummary.starsText(versionAverage)) on \(version)", comment: "kind:label · a version's rating")
        guard let previousVersion, let previousAverage else { return current }
        let previous = String(localized: "\(RatingsSummary.starsText(previousAverage)) on \(previousVersion)", comment: "kind:label · a version's rating")
        return "\(current) · \(previous)"
    }

    /// "Rating 4.6 stars, 3.9 on version 1.4".
    var accessibilityText: String {
        guard let average else { return String(localized: "Rating: no ratings yet", comment: "kind:accessibility-label") }
        let overall = String(localized: "Rating \(ReviewText.rating(average)) stars", comment: "kind:accessibility-label")
        guard let version, let versionAverage else { return overall }
        var text = overall + ", " + String(localized: "\(ReviewText.rating(versionAverage)) on version \(version)", comment: "kind:accessibility-label")
        if let previousVersion, let previousAverage {
            text += ", " + String(localized: "\(ReviewText.rating(previousAverage)) on \(previousVersion)", comment: "kind:accessibility-label")
        }
        return text
    }
}
