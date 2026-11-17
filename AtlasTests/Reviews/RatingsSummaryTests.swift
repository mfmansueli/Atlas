//
//  RatingsSummaryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The ratings card: Apple's average across storefronts, the written
/// reviews' stars, and whether the newest version is rated differently.
@Suite("Reviews · ratings")
struct RatingsSummaryTests {
    typealias Data = ReviewsTestData

    private func reviews(_ ratings: [Int], version: String, startingDaysAgo: Double = 1) -> [AppReview] {
        ratings.enumerated().map { index, rating in
            Data.review("\(version)-\(index)", rating: rating, version: version, daysAgo: startingDaysAgo + Double(index) * 0.1)
        }
    }

    @Test func theAverageWeighsEachStorefrontByItsRatings() {
        var ratings = StoreRatings.unchecked
        ratings.record(.rated(5), count: 100, inCountry: "US")
        ratings.record(.rated(3), count: 300, inCountry: "DE")
        ratings.record(.unrated, count: nil, inCountry: "JP")
        let summary = RatingsSummary.make(ratings: ratings, countries: ["US", "DE", "JP", "FR"], reviews: Data.reviews, version: "1.3", now: Data.now)
        #expect(summary.average == 3.5)
        #expect(summary.ratingCount == 400)
        #expect(summary.storefrontCount == 2)
        #expect(summary.averageText == "3.5")
        #expect(summary.countText == "400 ratings in 2 countries, Apple’s average. Bars: the 6 written reviews of the last 90 days.")
    }

    @Test func theBarsCountOnlyTheLastNinetyDays() {
        let old = Data.review("old", rating: 5, daysAgo: 120)
        let summary = RatingsSummary.make(ratings: .unchecked, countries: [], reviews: Data.reviews + [old], version: nil, now: Data.now)
        #expect(summary.histogram.total == 6)
        #expect(summary.histogram.count(stars: 1) == 2)
        #expect(summary.histogram.share(stars: 2) == 2.0 / 6.0)
        #expect(summary.average == nil)
        #expect(summary.averageText == "–")
        #expect(summary.countText.hasPrefix("No ratings read from the App Store yet."))
    }

    @Test func aClearlyLowerVersionIsSaidForSure() throws {
        let low = reviews(Array(repeating: 1, count: 12) + [2, 2, 3], version: "1.3")
        let all = low + reviews(Array(repeating: 5, count: 15) + [4, 4, 3], version: "1.2", startingDaysAgo: 20)
        let comparison = try #require(VersionRatingComparison.make(reviews: all, version: "1.3"))
        #expect(comparison.outcome == .lower(.sure))
        #expect(comparison.count == 15)
        #expect(comparison.earlierCount == 18)
        #expect(comparison.againstText.hasPrefix("Lower than before 1.3: 4.8 from 18 reviews. Sure."))
        #expect(comparison.sinceText.hasPrefix("Since 1.3 ("))
    }

    @Test func tooFewReviewsArentCompared() throws {
        let all = reviews([1, 1, 2], version: "1.3") + reviews(Array(repeating: 5, count: 15), version: "1.2", startingDaysAgo: 20)
        let comparison = try #require(VersionRatingComparison.make(reviews: all, version: "1.3"))
        #expect(comparison.outcome == .tooFew)
        #expect(comparison.againstText.hasPrefix("Too few reviews to compare"))
        #expect(VersionRatingComparison.make(reviews: all, version: nil) == nil)
        // Nothing before the version: nothing to compare with.
        #expect(VersionRatingComparison.make(reviews: reviews([1, 2], version: "1.3"), version: "1.3") == nil)
    }

    @Test func aSmallDifferenceIsAboutTheSame() {
        let sample = [5, 4, 5, 3, 4, 5, 4, 5, 3, 4, 5, 4]
        let earlier = [4, 5, 4, 3, 5, 4, 5, 4, 3, 5, 4, 5]
        #expect(VersionRatingComparison.outcome(sample, against: earlier) == .same)
        #expect(VersionRatingComparison.outcome(Array(repeating: 5, count: 10), against: Array(repeating: 5, count: 10)) == .same)
        #expect(VersionRatingComparison.outcome(Array(repeating: 5, count: 10), against: Array(repeating: 4, count: 10)) == .higher(.sure))
    }
}
