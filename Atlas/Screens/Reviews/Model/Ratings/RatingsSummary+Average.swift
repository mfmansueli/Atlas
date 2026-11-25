//
//  RatingsSummary+Average.swift
//  Atlas
//

import Foundation

// The average on its own, for the lines that quote it beside something
// else: the toolbar's “4.7 ★ · 4 reviews without a reply” and the
// Overview's Ratings & Reviews row.
extension RatingsSummary {
    /// The App Store's average across the storefronts the Ratings card asks
    /// (each answer is kept a day), or nil before any has a rating.
    @MainActor
    static func average(of app: StoreApp, archive: ReviewsArchive, services: any ReviewsServices, now: Date = .now) async -> Double? {
        let countries = countries(for: archive.reviews)
        let ratings = await services.ratings(for: app, countries: countries)
        return make(
            ratings: ratings, countries: countries, reviews: archive.reviews, writtenCount: archive.writtenCount,
            version: archive.currentVersion, now: now
        ).average
    }

    /// “4.7 ★”.
    static func starsText(_ average: Double) -> String {
        String(localized: "\(ReviewText.rating(average)) ★", comment: "kind:other")
    }
}
