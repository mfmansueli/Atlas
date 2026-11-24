//
//  RatingsSummary.swift
//  Atlas
//

import Foundation

/// The Ratings card: Apple's average and count across the storefronts
/// read, how many of those ratings came without a written review, the
/// written reviews' stars, and the current version against before.
struct RatingsSummary: Hashable, Sendable {
    /// Apple's averages weighted by each storefront's number of ratings;
    /// nil before any storefront answered with a rating.
    var average: Double?
    var ratingCount = 0
    /// Storefronts that have a rating, of the ones read.
    var storefrontCount = 0
    /// Apple's count of the app's written reviews; nil when unknown.
    var writtenCount: Int?
    /// The written reviews of the last `days`.
    var histogram = StarHistogram()
    var days = RatingsSummary.days
    var comparison: VersionRatingComparison?

    /// How far back the bars count written reviews.
    static let days = 90

    /// How many storefronts are asked for their rating, besides the US.
    static let countryLimit = 40

    /// The storefronts asked for their rating: the ones with the most
    /// reviews, and the United States.
    static func countries(for reviews: [AppReview]) -> Set<String> {
        var countries = Set(
            Dictionary(grouping: reviews.filter { !$0.territory.isEmpty }, by: \.territory)
                .sorted { $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count }
                .prefix(countryLimit)
                .map(\.key)
        )
        countries.insert("US")
        return countries
    }

    static func make(
        ratings: StoreRatings,
        countries: Set<String>,
        reviews: [AppReview],
        writtenCount: Int? = nil,
        version: String?,
        now: Date
    ) -> RatingsSummary {
        var summary = RatingsSummary()
        summary.writtenCount = writtenCount
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

    /// Ratings that came with stars only, no written review: Apple's count
    /// minus the written reviews. Nil when either is unknown, or when the
    /// written reviews outnumber the ratings (a reset rating summary).
    var starsOnlyCount: Int? {
        guard let writtenCount, ratingCount > 0, ratingCount >= writtenCount else { return nil }
        return ratingCount - writtenCount
    }

    /// 0 to 1: the share of the ratings that came with a written review.
    var writtenShare: Double {
        guard let starsOnlyCount, ratingCount > 0 else { return 0 }
        return Double(ratingCount - starsOnlyCount) / Double(ratingCount)
    }

    /// "Stars only: 11,634".
    var starsOnlyText: String? {
        starsOnlyCount.map { String(localized: "Stars only: \(ReviewText.count($0))", comment: "kind:label") }
    }

    /// "Written: 1,206".
    var writtenText: String? {
        guard starsOnlyCount != nil, let writtenCount else { return nil }
        return String(localized: "Written: \(ReviewText.count(writtenCount))", comment: "kind:label")
    }

    /// "11,634 of 12,840 ratings have no written review.", for VoiceOver
    /// and the bar's help.
    var starsOnlySentence: String? {
        guard let starsOnlyCount else { return nil }
        return String(
            localized: "\(ReviewText.count(starsOnlyCount)) of \(ReviewText.count(ratingCount)) ratings have no written review.",
            comment: "kind:accessibility"
        )
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
