//
//  ProposePricesCountryTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_prices` setting one country's price point on an in-app
/// purchase, and sending a country back to Apple's automatic price.
@MainActor
@Suite("propose_prices: in-app purchases and automatic prices")
struct ProposePricesCountryTests {
    private typealias Fixtures = MCPPricingFixtures
    private let changes = ChangeQueue()

    private func propose(_ arguments: [String: JSONValue], product: String) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        arguments["productId"] = .string(product)
        return try await Fixtures.call(ProposePricesTool(), arguments, changes: changes)
    }

    private func sheet(_ productID: String) throws -> ProductPriceSheet {
        let product = try #require(DebugPricingCatalog.catalog(for: Fixtures.lumen).product(id: productID))
        return DebugPriceSheets.sheet(for: product, commission: .smallBusiness, canReadSales: true)
    }

    /// A point well under today's price in the territory.
    private func lowerPrice(_ productID: String, _ territoryID: String) throws -> Decimal {
        let sheet = try sheet(productID)
        let current = try #require(sheet.prices[territoryID]?.current.customerPrice)
        let points = try #require(sheet.ladders[territoryID]?.points)
        return try #require(points.last { $0.customerPrice < current * Decimal(9) / 10 }).customerPrice
    }

    @Test func anInAppPurchasesPriceWaitsAsItsPriceSchedule() async throws {
        let price = try lowerPrice(Fixtures.lifetime, "BRA")
        let outcome = try await propose(["territory": "BRA", "price": MCPPriceValue.json(price)], product: Fixtures.lifetime)

        let id = InAppPurchaseCountryPrices.changeID(productID: Fixtures.lifetime)
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["changeId"] == .string(id))
        let change = try #require(changes.change(id: id))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.creation?.fields.map(\.id) == ["BRA.price"])
        #expect(change.requests.first?.path == InAppPurchaseCountryPrices.path)
        #expect(change.blockedReason == nil)
    }

    @Test func severalInAppPurchasePricesShareOneChange() async throws {
        let prices: [JSONValue] = try [
            ["territory": "BRA", "price": MCPPriceValue.json(lowerPrice(Fixtures.lifetime, "BRA"))],
            ["territory": "IND", "price": MCPPriceValue.json(lowerPrice(Fixtures.lifetime, "IND"))],
        ]
        let outcome = try await propose(["prices": .array(prices)], product: Fixtures.lifetime)
        #expect(outcome.result["queued"] == 2)
        #expect(changes.changes.count == 1)
        #expect(changes.changes.first?.creation?.fields.count == 2)
    }

    @Test func anInAppPurchaseGoesBackToAutomatic() async throws {
        // Brazil gets a manual price first, then goes back.
        let price = try lowerPrice(Fixtures.lifetime, "BRA")
        _ = try await propose(["territory": "BRA", "price": MCPPriceValue.json(price)], product: Fixtures.lifetime)
        let outcome = try await propose(["territory": "BRA", "automatic": true], product: Fixtures.lifetime)
        #expect(outcome.result["status"] == "unchanged")
        #expect(outcome.result["automatic"] == true)
        #expect(outcome.result["price"] == nil)
        #expect(changes.changes.isEmpty)
    }

    @Test func aTerritoryOnApplesPriceIsUnchangedAndTheBaseRefused() async throws {
        let outcome = try await propose(["territory": "CAN", "automatic": true], product: Fixtures.lifetime)
        #expect(outcome.result["status"] == "unchanged")
        // Japan's price is set by hand (`DebugPriceSheets`): it goes back.
        let japan = try await propose(["territory": "JPN", "automatic": true], product: Fixtures.lifetime)
        #expect(japan.result["status"] == "queued")
        #expect(changes.changes.first?.creation?.fields.map(\.id) == ["JPN.automatic"])
        let base = try await propose(["territory": "USA", "automatic": true], product: Fixtures.lifetime)
        #expect(base.result["status"] == "refused")
        #expect(base.result["reason"]?.stringValue?.contains("base territory") == true)
    }

    @Test func aSubscriptionGoesBackToItsEqualizedPrice() async throws {
        let sheet = try sheet(Fixtures.annual)
        let mexico = try #require(sheet.prices["MEX"])
        try #require(PricingRow.differs(mexico.current.customerPrice, mexico.equalized.customerPrice))

        let outcome = try await propose(["territory": "MEX", "automatic": true], product: Fixtures.annual)
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["automatic"] == true)
        let change = try #require(changes.change(id: Fixtures.changeID("MEX")))
        #expect(change.newValue == CurrencyFormat.forCurrency("MXN").format(mexico.equalized.customerPrice))
    }

    @Test func theBaseTerritoryHasNoAutomaticPrice() async throws {
        let outcome = try await propose(["territory": "USA", "automatic": true], product: Fixtures.annual)
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    @Test func automaticNeedsNoPrice() throws {
        let proposals = try MCPPriceProposal.list(from: MCPToolArguments(["prices": [["territory": "BRA", "automatic": true]]]))
        #expect(proposals.proposals == [MCPPriceProposal(territory: "BRA", price: 0, isAutomatic: true)])
    }
}
#endif
