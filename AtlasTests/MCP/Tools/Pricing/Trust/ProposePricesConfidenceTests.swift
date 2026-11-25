//
//  ProposePricesConfidenceTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// propose_prices checks the assistant's how sure like an edit: never
/// above what Atlas's own evidence supports in the country, unless the
/// price mirrors the project's; no price on a simulated grid; evidence
/// checked and written on the change as its details.
@MainActor
@Suite("propose_prices · how sure and evidence")
struct ProposePricesConfidenceTests {
    private typealias Fixtures = MCPPricingFixtures
    private let changes = ChangeQueue()

    private func propose(_ arguments: [String: JSONValue], pricing: (any PricingServices)? = nil) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        arguments["productId"] = .string(Fixtures.annual)
        return try await Fixtures.call(ProposePricesTool(), arguments, changes: changes, pricing: pricing)
    }

    private func scenario(_ scenario: DebugPricingConfidenceSales.Scenario) -> DebugConfidencePricingServices {
        DebugConfidencePricingServices(scenario: scenario)
    }

    /// A price point in the territory other than today's.
    private func otherPoint(_ territoryID: String) throws -> Decimal {
        let sheet = try Fixtures.sheet(Fixtures.annual)
        let current = try #require(sheet.prices[territoryID]?.current.customerPrice)
        let points = try #require(sheet.ladders[territoryID]?.points)
        return try #require(points.last { $0.customerPrice < current }?.customerPrice)
    }

    // MARK: - How sure

    @Test func noSalesYetCapsHowSureAtNotVerySure() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9), "confidence": 2], pricing: scenario(.noSales))
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"] == .string(
            "In Brazil, how sure can be at most Not very sure (1): Purchasing power only: no sales yet. Send confidence 1 or leave it out."
        ))
        #expect(changes.changes.isEmpty)
        #expect(outcome.logLines.first?.outcome == .refused)
    }

    @Test func aConfidenceWithinTheCapIsQueuedWithIt() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9), "confidence": 1], pricing: scenario(.noSales))
        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.change(id: Fixtures.changeID("BRA")))
        #expect(change.layers?.confidence == .notVerySure)
    }

    @Test func withoutAConfidenceNothingIsCapped() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9)], pricing: scenario(.noSales))
        #expect(outcome.result["status"] == "queued")
        #expect(changes.change(id: Fixtures.changeID("BRA"))?.layers == nil)
    }

    @Test func enoughSalesAllowFairlySureButNotSure() async throws {
        let fairly = try await propose(["territory": "BRA", "price": .double(109.9), "confidence": 2], pricing: scenario(.fairly))
        #expect(fairly.result["status"] == "queued")

        let sure = try await propose(["territory": "BRA", "price": .double(109.9), "confidence": 3], pricing: scenario(.fairly))
        #expect(sure.result["status"] == "refused")
        let reason = try #require(sure.result["reason"]?.stringValue)
        #expect(reason.hasPrefix("In Brazil, how sure can be at most Fairly sure (2): Brazil: 2,400 page views and 40 trials in 90 days."))
        #expect(reason.hasSuffix("Send confidence 2 or lower."))
    }

    @Test func anEarlierChangeWithAClearResultAllowsSure() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9), "confidence": 3], pricing: scenario(.sure))
        #expect(outcome.result["status"] == "queued")
        #expect(changes.change(id: Fixtures.changeID("BRA"))?.layers?.confidence == .sure)
    }

    @Test func eachPriceInABatchIsCheckedWithItsOwnConfidence() async throws {
        let india = try otherPoint("IND")
        let outcome = try await propose([
            "prices": [
                ["territory": "BRA", "price": .double(109.9), "confidence": 1],
                ["territory": "IND", "price": MCPPriceValue.json(india)],
            ],
            "confidence": 2,
        ], pricing: scenario(.noSales))
        let results = try Fixtures.results(outcome)
        #expect(results["BRA"]?["status"] == "queued")
        #expect(results["IND"]?["status"] == "refused")
        #expect(results["IND"]?["reason"]?.stringValue?.hasPrefix("In India, how sure can be at most Not very sure (1)") == true)
        #expect(outcome.result["queued"] == 1)
        #expect(outcome.result["refused"] == 1)
        #expect(changes.change(id: Fixtures.changeID("BRA"))?.layers?.confidence == .notVerySure)
    }

    @Test func manyCountriesAtOnceAreCappedOneByOne() async throws {
        let outcome = try await propose(["territories": ["BRA"], "price": .double(109.9), "confidence": 3], pricing: scenario(.fairly))
        let results = try Fixtures.results(outcome)
        #expect(results["BRA"]?["status"] == "refused")
        #expect(results["BRA"]?["reason"]?.stringValue?.contains("at most Fairly sure (2)") == true)
    }

    @Test func aPriceFromTheProjectIsntCappedBySales() async throws {
        let evidence: JSONValue = [["source": "project", "detail": "Products.storekit:42 says R$ 109,90"]]
        let outcome = try await propose(
            ["territory": "BRA", "price": .double(109.9), "confidence": 3, "evidence": evidence], pricing: scenario(.noSales)
        )
        #expect(outcome.result["status"] == "queued")
        let layers = try #require(changes.change(id: Fixtures.changeID("BRA"))?.layers)
        #expect(layers.confidence == .sure)
        #expect(layers.details == "Based on: Project · Products.storekit:42 says R$ 109,90")
    }

    @Test func todaysPriceWithdrawsWhateverTheConfidence() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(219.9), "confidence": 3], pricing: scenario(.noSales))
        #expect(outcome.result["status"] == "unchanged")
    }

    // MARK: - Grid

    @Test func aCountryWithoutApplesPointsIsRefusedUntilTheyArrive() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9)], pricing: PartialGridPricingServices(missing: ["BRA"]))
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"] == "Checking Apple’s prices in Brazil first. Try again in a minute.")
        #expect(changes.change(id: Fixtures.changeID("BRA")) == nil)
    }

    @Test func applesPointsAreReadBeforeProposing() async throws {
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9)], pricing: PartialGridPricingServices(missing: []))
        #expect(outcome.result["status"] == "queued")
    }

    // MARK: - Evidence

    @Test func evidenceBecomesTheChangesDetails() async throws {
        let evidence: JSONValue = [
            ["source": "analytics", "detail": "Brazil, 28 days: 720 page views"],
            ["source": "Outside", "detail": "Spotify Brazil: R$ 21,90"],
        ]
        let outcome = try await propose(
            ["territory": "BRA", "price": .double(109.9), "confidence": 2, "evidence": evidence], pricing: scenario(.fairly)
        )
        #expect(outcome.result["status"] == "queued")
        let layers = try #require(changes.change(id: Fixtures.changeID("BRA"))?.layers)
        #expect(layers.details == "Based on: Analytics · Brazil, 28 days: 720 page views; Outside source · Spotify Brazil: R$ 21,90")
        #expect(layers.confidence == .fairlySure)
    }

    @Test func salesEvidenceIsRefusedWhenAtlasReadsNoSales() async throws {
        var services = DebugPricingServices()
        services.canReadSales = false
        let evidence: JSONValue = [["source": "sales", "detail": "Brazil, 90 days: 40 trials"]]
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9), "evidence": evidence], pricing: services)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"] == .string(
            "Sales evidence can’t be checked here. Purchasing power alone: this key’s role can’t read Sales and Trends. "
                + "Base it on priceIndex, exchangeRates, project or outside."
        ))
        #expect(changes.changes.isEmpty)
    }

    @Test func salesEvidenceIsRefusedBeforeAnySales() async throws {
        let evidence: JSONValue = [["source": "sales", "detail": "Brazil, 90 days: 40 trials"]]
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9), "evidence": evidence], pricing: scenario(.noSales))
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.hasPrefix("Lumen Plus Annual has no sales yet") == true)
    }

    @Test func pageViewsStillCountBeforeAnySales() async throws {
        let evidence: JSONValue = [["source": "analytics", "detail": "Brazil, 90 days: 9 page views"]]
        let outcome = try await propose(["territory": "BRA", "price": .double(109.9), "evidence": evidence], pricing: scenario(.noSales))
        #expect(outcome.result["status"] == "queued")
    }

    @Test func aLongOrLoudDetailIsRefused() async throws {
        let long: JSONValue = [["source": "outside", "detail": .string(String(repeating: "a", count: 61))]]
        let tooLong = try await propose(["territory": "BRA", "price": .double(109.9), "evidence": long])
        #expect(tooLong.result["reason"] == "evidence[0].detail is 61 characters; at most 60. Keep the number that decides it.")

        let loud: JSONValue = [["source": "outside", "detail": "Just R$ 21,90 at Spotify!"]]
        let refused = try await propose(["territory": "BRA", "price": .double(109.9), "evidence": loud])
        let reason = try #require(refused.result["reason"]?.stringValue)
        #expect(reason.contains("uses “just”"))
        #expect(reason.contains("has “!”"))
        #expect(changes.changes.isEmpty)
    }

    @Test func anUnknownSourceIsAnArgumentError() async throws {
        await #expect(throws: MCPToolError.self) {
            try await propose(["territory": "BRA", "price": .double(109.9), "evidence": [["source": "gut feeling", "detail": "Brazil"]]])
        }
    }

    // MARK: - Contract

    @Test func theSchemaOffersEvidenceAndAPerPriceConfidence() {
        let schema = ProposePricesTool().definition.inputSchema
        #expect(schema["properties"]?["evidence"]?["items"]?["properties"]?["source"] != nil)
        #expect(schema["properties"]?["confidence"]?["type"] == "integer")
        #expect(schema["properties"]?["prices"]?["items"]?["properties"]?["confidence"]?["type"] == "integer")
        #expect(ProposePricesTool().definition.description.contains("howSure"))
        // The server still checks a per-price confidence's range.
        #expect(AssistantTextCheck.refusal(["prices": [["territory": "BRA", "price": 1, "confidence": 4]]], schema: schema)
            == "prices[0].confidence is 4; send 1 (not very sure), 2 (fairly sure) or 3 (sure).")
    }

    @Test func theInstructionsSayToReadHowSureFirst() {
        #expect(MCPEndpoint.instructions.contains("get_prices' howSure and evidence"))
        #expect(MCPEndpoint.instructions.contains("purchasing power alone, so it's Not very sure"))
        #expect(MCPEndpoint.instructions.contains("get_price_history"))
    }
}
#endif
