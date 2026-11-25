//
//  SimilarAppsCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Similar apps check")
struct SimilarAppsCheckTests {
    private typealias Fixture = ReviewRiskTextFixtures

    private func words(_ prefix: String, _ range: ClosedRange<Int>) -> [String] {
        range.map { "\(prefix)\($0)" }
    }

    private func risks(mine: String, other: String, otherLocale: String = "en-US") -> [ReviewRisk] {
        let sibling = ReviewRiskSiblingApp(appID: "app2", name: "Alba Pro", primaryLocale: otherLocale, descriptions: [otherLocale: other])
        return Fixture.risks(SimilarAppsCheck().run(Fixture.facts([Fixture.listing(.description, mine)], siblings: [sibling])))
    }

    @Test func aCopiedDescriptionIsLikely() throws {
        let text = words("w", 1...30).joined(separator: " ")
        let risk = try #require(risks(mine: text, other: text).first)
        #expect(risk.id == "similarApps:similar.app2")
        #expect(risk.level == .likely)
        #expect(risk.why.contains("100%"))
        #expect(risk.evidence.first?.place.contains("Alba Pro") == true)
    }

    @Test func aMostlySharedDescriptionIsACheck() throws {
        let mine = words("w", 1...30).joined(separator: " ")
        let other = (words("w", 1...25) + words("x", 1...5)).joined(separator: " ")
        let score = try #require(TextShingleSimilarity.similarity(mine, other))
        #expect(score > 0.6 && score < 0.8)
        let risk = try #require(risks(mine: mine, other: other).first)
        #expect(risk.level == .check)
        #expect(risk.evidence.first?.excerpt.hasPrefix("w1 w2 w3") == true)
    }

    @Test func differentAndShortTextsArentCompared() {
        let mine = words("w", 1...30).joined(separator: " ")
        #expect(risks(mine: mine, other: words("x", 1...30).joined(separator: " ")).isEmpty)
        #expect(risks(mine: "A calm daily journal", other: "A calm daily journal").isEmpty)
    }

    @Test func withoutTheOtherAppsItSaysWhy() {
        let facts = Fixture.facts([Fixture.listing(.description, "Text")])
        #expect(Fixture.isNotChecked(SimilarAppsCheck().run(facts)))
    }
}
