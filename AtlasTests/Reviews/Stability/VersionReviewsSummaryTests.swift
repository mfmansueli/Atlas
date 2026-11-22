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

    @Test func reviewsWithoutVersionsGiveNoSummary() {
        #expect(VersionReviewsSummary.make([review("a", 2, version: nil)]) == nil)
        #expect(VersionReviewsSummary.make([review("a", 2, version: "1.0")], newest: "1.1") == nil)
    }
}
