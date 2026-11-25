//
//  TrademarksAndNamesCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Trademarks and names check")
struct TrademarksAndNamesCheckTests {
    private typealias Fixture = ReviewRiskTextFixtures

    private func risks(_ texts: [ReviewRiskText]) -> [ReviewRisk] {
        Fixture.risks(TrademarksAndNamesCheck().run(Fixture.facts(texts)))
    }

    @Test func aTrademarkAsTheNameIsLikely() throws {
        let risk = try #require(risks([Fixture.listing(.name, "iPhone Cleaner")]).first)
        #expect(risk.id == "trademarksAndNames:storeListing.name.en-US.trademark")
        #expect(risk.level == .likely)
        #expect(risk.guideline == "5.2.5")
        #expect(risk.evidence.first?.excerpt.contains("iPhone") == true)
    }

    @Test func forIPhoneIsReferential() throws {
        #expect(risks([Fixture.listing(.subtitle, "Photo editor for iPhone and iPad")]).isEmpty)
        let name = try #require(risks([Fixture.listing(.name, "Notes for iPad")]).first)
        #expect(name.level == .check)
        #expect(name.howSure == .notVerySure)
    }

    @Test func macAndAppleCountOnlyAsWritten() throws {
        let pie = try #require(risks([Fixture.listing(.name, "Apple Pie Recipes")]).first)
        #expect(pie.level == .check)
        #expect(risks([Fixture.listing(.name, "apple pie recipes"), Fixture.listing(.subtitle, "Mac and cheese, macro tracker")]).count == 1)
    }

    @Test func trademarksInKeywordsAreWorthALook() throws {
        let risk = try #require(risks([Fixture.listing(.keywords, "iphone,notes,ipad,diary")]).first)
        #expect(risk.id == "trademarksAndNames:storeListing.keywords.en-US.trademark")
        #expect(risk.level == .check)
        #expect(risk.why.contains("2"))
    }

    @Test func aNameFullOfSeparatorsIsLikely() throws {
        let risk = try #require(risks([Fixture.listing(.name, "Notes | Todo | Planner | Journal")]).first)
        #expect(risk.id == "trademarksAndNames:storeListing.name.en-US.stuffing")
        #expect(risk.level == .likely)
        #expect(StoreTextNameStuffing.separators(in: "To-Do: Lists & Notes, 24/7").count == 1)
        #expect(!StoreTextNameStuffing.isStuffed("Alba – Daily Motivation"))
    }

    @Test func theSubtitleRepeatingTheNameIsWorthALook() {
        let found = risks([Fixture.listing(.name, "Lumen Journal"), Fixture.listing(.subtitle, "lumen  journal")])
        #expect(found.map(\.id) == ["trademarksAndNames:storeListing.subtitle.en-US.sameAsName"])
    }

    @Test func keywordsRepeatingTheNameAreWorthALook() throws {
        let found = risks([Fixture.listing(.name, "Lumen Journal"), Fixture.listing(.keywords, "journal,diary,mood,lumen journal")])
        let risk = try #require(found.first)
        #expect(risk.id == "trademarksAndNames:storeListing.keywords.en-US.repeatsName")
        #expect(risk.evidence.first?.excerpt == "journal, lumen journal")
    }

    @Test func aCleanListingHasNoRisks() {
        let found = risks([
            Fixture.listing(.name, "Lumen"),
            Fixture.listing(.subtitle, "A calm daily journal"),
            Fixture.listing(.keywords, "diary,mood,habits,gratitude"),
            Fixture.listing(.description, "Works on iPhone, iPad and Apple Watch."),
        ])
        #expect(found.isEmpty)
    }
}
