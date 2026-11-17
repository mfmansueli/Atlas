//
//  RatingsSummary.swift
//  Atlas
//

import Foundation

/// The Ratings card: Apple's average and count across the storefronts
/// read, the written reviews' stars, and the current version against
/// before.
struct RatingsSummary: Hashable, Sendable {
    /// Apple's averages weighted by each storefront's number of ratings;
    /// nil before any storefront answered with a rating.
    var average: Double?
    var ratingCount = 0
    /// Storefronts that have a rating, of the ones read.
    var storefrontCount = 0
    /// The written reviews of the last `days`.
    var histogram = StarHistogram()
    var days = RatingsSummary.days
    var comparison: VersionRatingComparison?

    /// How far back the bars count written reviews.
    static let days = 90

    static func make(ratings: StoreRatings, countries: Set<String>, reviews: [AppReview], version: String?, now: Date) -> RatingsSummary {
        var summary = RatingsSummary()
        var weighted = 0.0
        for country in countries {
            guard case let .rated(average) = ratings.status(inCountry: country), let count = ratings.count(inCountry: country), count > 0 else { continue }
            weighted += average * Double(count)
            summary.ratingCount += count
            summary.storefrontCount += 1
        }
        summary.average = summary.ratingCount > 0 ? weighted / Double(summary.ratingCount) : nil
        let start = now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
        summary.histogram = StarHistogram(reviews.filter { $0.date >= start })
        summary.comparison = VersionRatingComparison.make(reviews: reviews, version: version)
        return summary
    }

    /// "4.6", or "–" before Apple answered.
    var averageText: String {
        average.map(ReviewText.rating) ?? "–"
    }

    /// "12,840 ratings in 23 countries, Apple’s average. Bars: the 1,206
    /// written reviews of the last 90 days."
    var countText: String {
        let bars = histogram.total == 0
            ? String(localized: "No written reviews in the last \(days) days.")
            : String(localized: "Bars: the \(ReviewText.count(histogram.total)) written reviews of the last \(days) days.")
        guard ratingCount > 0 else { return String(localized: "No ratings read from the App Store yet.") + " " + bars }
        let places = storefrontCount == 1 ? String(localized: "1 country") : String(localized: "\(storefrontCount) countries")
        let ratings = ratingCount == 1 ? String(localized: "1 rating") : String(localized: "\(ReviewText.count(ratingCount)) ratings")
        return String(localized: "\(ratings) in \(places), Apple’s average.") + " " + bars
    }
}
