//
//  StoreTextGuidelineAllowanceTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("What an app may say in store text")
struct StoreTextGuidelineAllowanceTests {
    @Test func theKidsCategoryAllowsForKids() {
        let issues = StoreTextGuidelineCheck.issues(in: "Bedtime Stories for Kids", for: .subtitle)
        #expect(issues.map(\.kind) == [.kidsTerms])
        #expect(StoreTextGuidelineAllowance(isKidsCategory: true).allowed(issues, in: .subtitle).isEmpty)
        #expect(StoreTextGuidelineAllowance().allowed(issues, in: .subtitle) == issues)
    }

    @Test func theApprovedNameCountsInTheNameAndSubtitleOnly() {
        let allowance = StoreTextGuidelineAllowance(approvedNames: ["Best Photo: Google Edition"])
        let name = StoreTextGuidelineCheck.issues(in: "Best Photo for Google Fans", for: .name)
        #expect(!name.isEmpty)
        #expect(allowance.allowed(name, in: .name).isEmpty)
        let description = StoreTextGuidelineCheck.issues(in: "Free to download", for: .description)
        #expect(allowance.allowed(description, in: .description) == description)
    }

    @Test func wordsCountWhole() {
        let allowance = StoreTextGuidelineAllowance(approvedNames: ["Bestie Chat"])
        let issues = StoreTextGuidelineCheck.issues(in: "Best Chat", for: .name)
        #expect(allowance.allowed(issues, in: .name) == issues)
    }

    @Test func theToolsBindItAroundTheirChecks() {
        let kids = StoreTextGuidelineAllowance(isKidsCategory: true)
        let inside = StoreTextGuidelineAllowance.$current.withValue(kids) {
            StoreTextGuidelineCheck.issues(in: "Stories for Kids", for: .subtitle)
        }
        #expect(inside.isEmpty)
        #expect(StoreTextGuidelineCheck.issues(in: "Stories for Kids", for: .subtitle).map(\.kind) == [.kidsTerms])
    }

    @Test func onlyForKidsMakesTheAgeRatingWorthReading() {
        #expect(StoreTextGuidelineAllowance.needsAgeRating([("Stories for Kids", .subtitle)]))
        #expect(!StoreTextGuidelineAllowance.needsAgeRating([("Stories for Kids", .whatsNew), ("Calm stories", .name)]))
    }

    @Test func theKidsAgeBandComesFromTheDeclaration() {
        #expect(AgeRatingValues(apiValues: ["kidsAgeBand": .string("SIX_TO_EIGHT")]).isKidsCategory)
        #expect(AgeRatingValues(apiValues: ["kidsAgeBand": .string("SIX_TO_EIGHT")]).kidsAgeBand == "SIX_TO_EIGHT")
        #expect(!AgeRatingValues(apiValues: ["kidsAgeBand": .null]).isKidsCategory)
        #expect(!AgeRatingValues().isKidsCategory)
        #expect(AgeRatingDeclarationAttributes(values: ["kidsAgeBand": .string("NINE_TO_ELEVEN")]).kidsAgeBand == "NINE_TO_ELEVEN")
    }
}
