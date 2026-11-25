//
//  PayElsewhereCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Paying outside the App Store check")
struct PayElsewhereCheckTests {
    private typealias Fixture = ReviewRiskTextFixtures

    private func risks(_ texts: [ReviewRiskText]) -> [ReviewRisk] {
        Fixture.risks(PayElsewhereCheck().run(Fixture.facts(texts)))
    }

    @Test func aCheaperWebsiteOutsideTheUSIsLikely() throws {
        let risk = try #require(risks([Fixture.listing(.description, "Lumen Plus ist günstiger auf unserer Website.", locale: "de-DE")]).first)
        #expect(risk.id == "payElsewhere:storeListing.description.de-DE.payElsewhere")
        #expect(risk.level == .likely)
        #expect(risk.evidence.first?.excerpt.contains("unserer Website") == true)
    }

    @Test func theUSLocaleIsOnlyACheck() throws {
        let risk = try #require(risks([Fixture.listing(.description, "Subscribe on our website for a lower price.")]).first)
        #expect(risk.level == .check)
        #expect(risk.why.contains("US"))
    }

    @Test func paymentLinksAreFound() {
        let found = risks([
            Fixture.listing(.promotionalText, "Soutenez-nous sur https://patreon.com/lumen", locale: "fr-FR"),
            Fixture.listing(.whatsNew, "Compare plans at https://lumen.app/pricing today.", locale: "en-GB"),
        ])
        #expect(found.map(\.level) == [.likely, .likely])
    }

    @Test func paymentServicesForGoodsAreUnsure() throws {
        let risk = try #require(risks([Fixture.listing(.description, "Pay with PayPal at checkout for your printed books.", locale: "en-GB")]).first)
        #expect(risk.level == .check)
        #expect(risk.howSure == .notVerySure)
    }

    @Test func newslettersAndBalancesArentPayments() {
        let found = risks([
            Fixture.listing(.description, "Subscribe to our newsletter on our website.", locale: "en-GB"),
            Fixture.listing(.description, "Track your PayPal and Stripe balances in one place.", locale: "en-AU"),
            Fixture.listing(.keywords, "patreon,donate", locale: "en-GB"),
        ])
        #expect(found.isEmpty)
    }

    @Test func captionsAreRead() throws {
        let caption = Fixture.text(.caption, "Buy Pro on our website", locale: "en-GB", owner: "2")
        let risk = try #require(risks([caption]).first)
        #expect(risk.fix.tool == "propose_captions")
        #expect(risk.fix.arguments["slot"] == "2")
    }
}
