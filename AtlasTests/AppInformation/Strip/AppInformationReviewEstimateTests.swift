//
//  AppInformationReviewEstimateTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// "19 suggestions · about 10 min": half a minute per suggestion, rounded
/// up, never under a minute.
@Suite("AppInformationReviewEstimate")
struct AppInformationReviewEstimateTests {
    @Test(arguments: [(1, 1), (2, 1), (3, 2), (4, 2), (19, 10), (20, 10), (41, 21)])
    func halfAMinuteEachRoundedUp(count: Int, minutes: Int) {
        #expect(AppInformationReviewEstimate.minutes(for: count) == minutes)
    }

    @Test func nothingToReviewTakesNoTime() {
        #expect(AppInformationReviewEstimate.minutes(for: 0) == 0)
        #expect(AppInformationReviewEstimate.text(for: 0) == "No suggestions waiting")
    }

    @Test func theLineSaysHowManyAndAboutHowLong() {
        #expect(AppInformationReviewEstimate.text(for: 19) == "19 suggestions · about 10 min")
        #expect(AppInformationReviewEstimate.text(for: 1) == "1 suggestion · about 1 min")
        #expect(AppInformationReviewEstimate.text(for: 4) == "4 suggestions · about 2 min")
    }

    @Test func voiceOverHearsTheWholeWords() {
        #expect(AppInformationReviewEstimate.accessibilityText(for: 19) == "19 suggestions, about 10 minutes to review")
        #expect(AppInformationReviewEstimate.accessibilityText(for: 0) == "No suggestions waiting")
    }
}
