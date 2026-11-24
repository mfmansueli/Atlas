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

    @Test func ratingsWithoutAWrittenReviewAreTheRestOfApplesCount() {
        var ratings = StoreRatings.unchecked
        ratings.record(.rated(4.7), count: 10000, inCountry: "US")
        ratings.record(.rated(4.4), count: 2840, inCountry: "DE")
        let summary = RatingsSummary.make(
            ratings: ratings, countries: ["US", "DE"], reviews: Data.reviews, writtenCount: 1206, version: "1.3", now: Data.now
        )
        #expect(summary.starsOnlyCount == 11634)
        #expect(abs(summary.writtenShare - 1206.0 / 12840.0) < 0.0001)
        // Numbers as this Mac writes them ("1,206", or "1.206" in pt-BR).
        let (written, starsOnly, all) = (ReviewText.count(1206), ReviewText.count(11634), ReviewText.count(12840))
        #expect(summary.writtenText == "Written: \(written)")
        #expect(summary.starsOnlyText == "Stars only: \(starsOnly)")
        #expect(summary.starsOnlySentence == "\(starsOnly) of \(all) ratings have no written review.")
    }

    @Test func starsOnlyIsLeftOutWhenItCantBeTold() {
        var ratings = StoreRatings.unchecked
        ratings.record(.rated(4.5), count: 40, inCountry: "US")
        func summary(written: Int?, ratings: StoreRatings) -> RatingsSummary {
            RatingsSummary.make(ratings: ratings, countries: ["US"], reviews: Data.reviews, writtenCount: written, version: nil, now: Data.now)
        }
        // Apple's count of written reviews unknown.
        #expect(summary(written: nil, ratings: ratings).starsOnlyCount == nil)
        // No ratings read from the App Store yet.
        #expect(summary(written: 6, ratings: .unchecked).starsOnlyCount == nil)
        // More written reviews than ratings: the rating summary was reset.
        let reset = summary(written: 60, ratings: ratings)
        #expect(reset.starsOnlyCount == nil)
        #expect(reset.writtenText == nil)
        #expect(reset.writtenShare == 0)
        // Every rating written: none stars only, still shown.
        #expect(summary(written: 40, ratings: ratings).starsOnlyCount == 0)
    }

    @Test func theStorefrontsAskedAreTheOnesWithMostReviewsAndTheUS() {
        #expect(RatingsSummary.countries(for: []) == RatingsSummary.largeStorefronts)
        #expect(RatingsSummary.largeStorefronts.count == 40)
        #expect(RatingsSummary.largeStorefronts.isSuperset(of: ["US", "IT", "BR", "JP"]))
        // A small storefront joins when people review there.
        let iceland = Data.review("is1", "IS")
        #expect(RatingsSummary.countries(for: Data.reviews + [iceland]) == RatingsSummary.largeStorefronts.union(["IS"]))
        let many = (0..<50).flatMap { index in
            (0...index).map { Data.review("c\(index)-\($0)", String(format: "C%02d", index)) }
        }
        let countries = RatingsSummary.countries(for: many).subtracting(RatingsSummary.largeStorefronts)
        #expect(countries.count == RatingsSummary.countryLimit)
        #expect(countries.contains("C49"))
        #expect(!countries.contains("C00"))
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
