//
//  OverviewRatingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Analytics · the Overview's rating by version")
struct OverviewRatingTests {
    private func reviews(_ version: String, _ ratings: [Int]) -> [AppReview] {
        ratings.enumerated().map { index, rating in
            AppReview(
                id: "\(version)-\(index)", territory: "US", rating: rating, title: "", body: "", nickname: "",
                date: Date(timeIntervalSince1970: 1_790_000_000 + Double(index)), version: version
            )
        }
    }

    @Test func theCurrentVersionAgainstTheOneBefore() {
        let all = reviews("1.2", [5, 5]) + reviews("1.3", Array(repeating: 5, count: 12)) + reviews("1.4", Array(repeating: 2, count: 12))
        let rating = OverviewRating.make(average: 4.6, reviews: all, currentVersion: "1.4")
        #expect(rating.version == "1.4")
        #expect(rating.versionAverage == 2)
        #expect(rating.previousVersion == "1.3")
        #expect(rating.previousAverage == 5)
        #expect(rating.isLower)
        #expect(rating.versionsText?.contains("on 1.3") == true)
    }

    @Test func versionsOrderAsPeopleReadThem() {
        let all = reviews("1.9", [4]) + reviews("1.10", [3])
        let rating = OverviewRating.make(average: nil, reviews: all, currentVersion: "1.10")
        #expect(rating.previousVersion == "1.9")
        #expect(!rating.isLower, "Too few reviews to call it lower")
    }

    @Test func withoutReviewsOfTheVersionOnlyTheAverage() {
        let rating = OverviewRating.make(average: 4.1, reviews: reviews("1.3", [4]), currentVersion: "1.4")
        #expect(rating.average == 4.1)
        #expect(rating.version == nil)
        #expect(rating.versionsText == nil)
    }
}
