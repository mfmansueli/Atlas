//
//  MCPPriceEvidenceTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// propose_prices' evidence: read leniently, checked like a card's texts,
/// written as one details line.
@Suite("MCPPriceEvidence")
struct MCPPriceEvidenceTests {
    @Test(arguments: [
        ("analytics", MCPPriceEvidenceSource.analytics), ("App Analytics", .analytics), ("sales and trends", .sales),
        ("World Bank", .priceIndex), ("priceIndex", .priceIndex), ("FX", .exchangeRates), ("StoreKit", .project),
        ("competitor", .outside),
    ])
    func sourcesAreReadLeniently(text: String, source: MCPPriceEvidenceSource) {
        #expect(MCPPriceEvidenceSource.parse(text) == source)
    }

    @Test func anUnknownSourceIsNil() {
        #expect(MCPPriceEvidenceSource.parse("gut feeling") == nil)
    }

    @Test func oneObjectOrAListIsRead() throws {
        let one = try MCPPriceEvidence.read(["source": "outside", "detail": "  Spotify: R$ 21,90  "])
        #expect(one == [MCPPriceEvidence(source: .outside, detail: "Spotify: R$ 21,90")])
        #expect(try MCPPriceEvidence.read(nil).isEmpty)
        #expect(try MCPPriceEvidence.read(.null).isEmpty)
        #expect(throws: MCPToolError.self) { try MCPPriceEvidence.read(["not an object"]) }
    }

    @Test func detailsJoinEveryItem() {
        let evidence = [MCPPriceEvidence(source: .sales, detail: "Brazil, 90 days: 40 trials"), MCPPriceEvidence(source: .project, detail: "Paywall.swift:18")]
        #expect(MCPPriceEvidence.details(evidence) == "Based on: Sales · Brazil, 90 days: 40 trials; Project · Paywall.swift:18")
        #expect(MCPPriceEvidence.details([]) == nil)
    }

    @Test func theLongestDetailsStayWithinTheDetailsLimit() {
        let detail = String(repeating: "a", count: MCPPriceEvidence.detailLimit)
        let evidence = Array(repeating: MCPPriceEvidence(source: .outside, detail: detail), count: MCPPriceEvidence.itemLimit)
        #expect((MCPPriceEvidence.details(evidence)?.count ?? 0) <= AssistantTextLimits.details)
    }

    @Test func emptyLongAndBannedTextsAreProblems() {
        #expect(MCPPriceEvidence.textProblems("", field: "evidence[0].detail").first?.hasPrefix("evidence[0].detail is empty") == true)
        #expect(MCPPriceEvidence.textProblems(String(repeating: "a", count: 61), field: "d")
            == ["d is 61 characters; at most 60. Keep the number that decides it."])
        #expect(MCPPriceEvidence.textProblems("Seamlessly cheaper", field: "d")
            == ["d uses “seamlessly”, which Atlas never writes. Say what you read plainly."])
        #expect(MCPPriceEvidence.textProblems("Adjusted for Brazil", field: "d").isEmpty)
        #expect(MCPPriceEvidence.textProblems("Cheap!", field: "d") == ["d has “!”, which Atlas never writes."])
    }

    @Test func tooManyItemsIsAProblem() {
        let evidence = Array(repeating: MCPPriceEvidence(source: .outside, detail: "Spotify: R$ 21,90"), count: MCPPriceEvidence.itemLimit + 1)
        #expect(MCPPriceEvidence.problems(evidence, sales: nil, productName: "Plus") == ["Send at most 4 evidence items, strongest first."])
    }

    @Test func salesEvidenceNeedsSalesAtlasReads() {
        let sales = [MCPPriceEvidence(source: .sales, detail: "Brazil, 90 days: 40 trials")]
        let analytics = [MCPPriceEvidence(source: .analytics, detail: "Brazil, 90 days: 9 page views")]
        let off = PricingSalesData(availability: .turnedOff)
        let none = PricingSalesData(availability: .noSalesYet)
        #expect(MCPPriceEvidence.problems(sales, sales: off, productName: "Plus").first?.hasPrefix("Sales evidence can’t be checked here.") == true)
        #expect(MCPPriceEvidence.problems(analytics, sales: off, productName: "Plus").first?.hasPrefix("Analytics evidence can’t be checked here.") == true)
        #expect(MCPPriceEvidence.problems(sales, sales: none, productName: "Plus").first?.hasPrefix("Plus has no sales yet") == true)
        #expect(MCPPriceEvidence.problems(analytics, sales: none, productName: "Plus").isEmpty)
        #expect(MCPPriceEvidence.problems(sales, sales: PricingSalesData(availability: .available), productName: "Plus").isEmpty)
        // A new subscription has no sales to check against.
        #expect(MCPPriceEvidence.problems(sales, sales: nil, productName: "Plus").isEmpty)
    }

    @Test func projectEvidenceMirrorsThePrice() {
        #expect(MCPPriceEvidence.mirrorsProject([MCPPriceEvidence(source: .project, detail: "Products.storekit:42")]))
        #expect(!MCPPriceEvidence.mirrorsProject([MCPPriceEvidence(source: .outside, detail: "Spotify")]))
    }
}
#endif
