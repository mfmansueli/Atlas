//
//  VersionReviewsSummaryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Reviews · the newest version's rating and crash mentions")
struct VersionReviewsSummaryTests {
    private func review(_ id: String, _ rating: Int, version: String?, body: String = "Nice app") -> AppReview {
        AppReview(id: id, territory: "US", rating: rating, title: "", body: body, nickname: "x", date: Date(), version: version)
    }

    /// "3.9" in this Mac's number format.
    private func stars(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    @Test(arguments: [
        "It keeps crashing when I open it", "Trava toda hora", "Stürzt ab beim Start", "起動するとすぐ落ちる", "一打开就闪退", "se cierra sola al abrir",
    ])
    func crashWordsAreFoundInManyLanguages(_ text: String) {
        #expect(ReviewCrashMentions.mentionsCrash(review("1", 1, version: "1.4", body: text)))
    }

    @Test func anOrdinaryReviewDoesntMentionACrash() {
        #expect(!ReviewCrashMentions.mentionsCrash(review("1", 5, version: "1.4", body: "Lovely journal, I use it every day")))
    }

    @Test func theNewestVersionIsComparedWithTheOneBefore() throws {
        let reviews = [
            review("a", 2, version: "1.10", body: "Crashes all the time"),
            review("b", 1, version: "1.10", body: "crash on launch"),
            review("c", 4, version: "1.10"),
            review("d", 5, version: "1.9"), review("e", 4, version: "1.9"), review("f", 5, version: "1.9"),
            review("g", 3, version: nil),
        ]
        let summary = try #require(VersionReviewsSummary.make(reviews))
        // 1.10 comes after 1.9.
        #expect(summary.version == "1.10")
        #expect(summary.count == 3)
        #expect(abs(summary.average - 7.0 / 3.0) < 0.0001)
        #expect(summary.crashMentions == 2)
        #expect(summary.previousVersion == "1.9")
        #expect(summary.previousAverage.map { abs($0 - 14.0 / 3.0) < 0.0001 } == true)
    }

    @Test func tooFewReviewsOnTheVersionBeforeLeaveItOut() throws {
        let reviews = [review("a", 2, version: "2.0"), review("b", 5, version: "1.9")]
        let summary = try #require(VersionReviewsSummary.make(reviews))
        #expect(summary.previousVersion == nil)
        #expect(summary.previousAverage == nil)
    }

    @Test func theBannerLeadsWithBothAveragesThenTheCrashes() {
        let summary = VersionReviewsSummary(version: "1.4", count: 11, average: 3.9, crashMentions: 6, previousVersion: "1.3", previousAverage: 4.7)
        #expect(summary.lead == "Version 1.4 averages \(stars(3.9)) ★ from 11 reviews; 1.3 averaged \(stars(4.7)) ★.")
        #expect(summary.detail(crashTimes: 3.2) == "6 of the 11 mention a crash, and crashes are \(AnalyticsText.times(3.2)) higher on 1.4.")
        #expect(summary.detail(crashTimes: nil) == "6 of the 11 mention a crash.")
    }

    @Test func theBannerWithoutAnEarlierVersionOrCrashMentions() {
        let summary = VersionReviewsSummary(version: "2.0", count: 1, average: 2, crashMentions: 0)
        #expect(summary.lead == "Version 2.0 averages \(stars(2)) ★ from 1 review.")
        #expect(summary.detail(crashTimes: 1.5) == "Crashes are \(AnalyticsText.times(1.5)) higher on 2.0.")
        #expect(summary.detail(crashTimes: nil) == nil)
    }

    @Test func reviewsWithoutVersionsGiveNoSummary() {
        #expect(VersionReviewsSummary.make([review("a", 2, version: nil)]) == nil)
        #expect(VersionReviewsSummary.make([review("a", 2, version: "1.0")], newest: "1.1") == nil)
    }
}
