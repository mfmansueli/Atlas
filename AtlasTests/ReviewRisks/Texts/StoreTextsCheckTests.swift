//
//  StoreTextsCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Store texts check")
struct StoreTextsCheckTests {
    private typealias Fixture = ReviewRiskTextFixtures

    private func risks(_ texts: [ReviewRiskText], allowance: StoreTextGuidelineAllowance = StoreTextGuidelineAllowance()) -> [ReviewRisk] {
        Fixture.risks(StoreTextsCheck().run(Fixture.facts(texts, allowance: allowance)))
    }

    @Test func pricingInTheDescriptionIsLikely() throws {
        let found = risks([Fixture.listing(.description, "Plan your week. Free to download and try.", locale: "de-DE")])
        let risk = try #require(found.first)
        #expect(found.count == 1)
        #expect(risk.id == "storeTexts:storeListing.description.de-DE.pricing")
        #expect(risk.level == .likely)
        #expect(risk.guideline == "2.3.7")
        #expect(risk.evidence.first?.excerpt.contains("Free") == true)
        #expect(risk.evidence.first?.locale == "de-DE")
        #expect(risk.fix.tool == "propose_listing_text")
        #expect(risk.fix.arguments == ["field": "description", "locale": "de-DE"])
    }

    @Test func otherRulesAndOtherFieldsAreAsCheck() {
        let comingSoon = risks([Fixture.listing(.description, "Widgets coming soon.")])
        #expect(comingSoon.map(\.level) == [.check])
        let whatsNew = risks([Fixture.listing(.whatsNew, "Now free for everyone.")])
        #expect(whatsNew.map(\.level) == [.check])
    }

    @Test func oneRiskPerTextAndRule() {
        let found = risks([
            Fixture.listing(.description, "Free beta for Android.", locale: "en-US"),
            Fixture.listing(.description, "Free beta for Android.", locale: "fr-FR"),
        ])
        #expect(found.count == 6)
        #expect(Set(found.map(\.id)).count == 6)
    }

    @Test func forKidsIsAllowedInTheKidsCategory() {
        let text = Fixture.listing(.subtitle, "Bedtime Stories for Kids")
        #expect(risks([text]).map(\.title).count == 1)
        #expect(risks([text], allowance: StoreTextGuidelineAllowance(isKidsCategory: true)).isEmpty)
    }

    @Test func theApprovedNameKeepsItsWords() {
        let name = Fixture.listing(.name, "Best Camera Pro")
        #expect(risks([name]).count == 1)
        #expect(risks([name], allowance: StoreTextGuidelineAllowance(approvedNames: ["Best Camera"])).isEmpty)
    }

    @Test func reviewNotesAndTrialPurchasesFollowTheirOwnRules() {
        let notes = Fixture.text(.reviewNotes, "Use the free trial: 7-day trial, sign in with the demo account.")
        let trial = Fixture.text(.inAppText, "7-day Trial", inAppField: .purchaseName, owner: "trial.name")
        #expect(risks([notes, trial]).isEmpty)
    }

    @Test func subscriptionTextsGoToInAppTexts() throws {
        let text = Fixture.text(.inAppText, "Free for 7 days", inAppField: .subscriptionDescription, owner: "plus.monthly.description")
        let risk = try #require(risks([text]).first)
        #expect(risk.level == .check)
        #expect(risk.fix.tool == "propose_in_app_texts")
        #expect(risk.fix.arguments["column"] == "plus.monthly.description")
    }

    @Test func eventsMayBeFree() {
        #expect(risks([Fixture.text(.eventText, "Free Weekend Challenge", owner: "event1")]).isEmpty)
        #expect(risks([Fixture.text(.eventText, "Pro for $4.99", owner: "event1")]).map(\.fix.tool) == ["propose_event_texts"])
    }

    @Test func everydayWordsArentFlagged() {
        let found = risks([
            Fixture.listing(.description, "Hands-free journaling. Feel free to export your notes, ad free."),
            Fixture.listing(.name, "Lumen"),
        ])
        #expect(found.isEmpty)
    }

    @Test func withoutTextsItSaysWhy() {
        #expect(Fixture.isNotChecked(StoreTextsCheck().run(ReviewRiskFacts(appID: "app1", appName: "Lumen"))))
    }
}
