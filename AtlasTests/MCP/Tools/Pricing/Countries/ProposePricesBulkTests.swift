//
//  ProposePricesBulkTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `propose_prices` over many countries at once: territories with one
/// price, automatic, acceptSuggestions or withdraw, and pricePointId.
@MainActor
@Suite("propose_prices: many countries at once")
struct ProposePricesBulkTests {
    private typealias Fixtures = MCPPricingFixtures
    private let changes = ChangeQueue()

    private func propose(
        _ arguments: [String: JSONValue],
        product: String = Fixtures.annual,
        modes: [StoreApp.ID: PricingMode] = [Fixtures.tempo: .keepPrices],
        pricingModes: PricingModeStore? = nil
    ) async throws -> MCPToolOutcome {
        var arguments = arguments
        if arguments["appId"] == nil { arguments["appId"] = .string(Fixtures.lumen) }
        if arguments["productId"] == nil { arguments["productId"] = .string(product) }
        return try await Fixtures.call(ProposePricesTool(), arguments, changes: changes, modes: modes, pricingModes: pricingModes)
    }

    private func status(_ outcome: MCPToolOutcome, _ territory: String) throws -> String? {
        try Fixtures.results(outcome)[territory]?["status"]?.stringValue
    }

    // MARK: - Automatic

    @Test func aRegionGoesBackToAutomaticWhereAPriceWasChosen() async throws {
        let sheet = try Fixtures.sheet(Fixtures.annual)
        let europe = TerritoryCatalog.standard.territories.filter { $0.region == .europe && sheet.prices[$0.id] != nil }
        let chosen = europe.filter { sheet.prices[$0.id]?.isCustom == true }.map(\.id)
        try #require(!chosen.isEmpty)

        let outcome = try await propose(["territories": "europe", "automatic": true])

        let results = try Fixtures.results(outcome)
        #expect(results.count == europe.count)
        #expect(outcome.result["queued"] == .int(chosen.count))
        #expect(outcome.result["refused"] == 0)
        #expect(Set(changes.changes.map(\.id)) == Set(chosen.map(Fixtures.changeID)))
        for territory in europe where chosen.contains(territory.id) {
            let id = territory.id
            let change = try #require(changes.change(id: Fixtures.changeID(id)))
            let equalized = try #require(sheet.prices[id]?.equalized.customerPrice)
            #expect(change.newValue == CurrencyFormat.forCurrency(territory.currencyCode).format(equalized))
            #expect(change.creation?.fields.first?.id == "\(id).automatic")
        }
    }

    @Test func theBaseTerritoryStaysWhenEveryCountryGoesAutomatic() async throws {
        let outcome = try await propose(["territories": "all", "automatic": true])
        #expect(try status(outcome, "USA") == "unchanged")
        #expect(changes.change(id: Fixtures.changeID("USA")) == nil)
        #expect(outcome.result["refused"] == 0)
    }

    @Test func anInAppPurchasesChosenCountriesGoBackTogether() async throws {
        let outcome = try await propose(["territories": "setByYou", "automatic": true], product: Fixtures.lifetime)

        let id = InAppPurchaseCountryPrices.changeID(productID: Fixtures.lifetime)
        let change = try #require(changes.change(id: id))
        #expect(changes.changes.count == 1)
        let fields = try #require(change.creation?.fields.map(\.id))
        #expect(fields.contains("JPN.automatic"))
        #expect(fields.allSatisfy { $0.hasSuffix(".automatic") })
        #expect(!fields.contains("USA.automatic"))
        // setByYou leaves the base out (MCPCountrySelectionTests), so the
        // U.S. isn't among the results at all.
        #expect(try status(outcome, "USA") == nil)
        #expect(try status(outcome, "JPN") == "queued")
    }

    // MARK: - One price

    @Test func oneEuroPriceGoesToEveryEuroCountry() async throws {
        let sheet = try Fixtures.sheet(Fixtures.annual)
        let euro = TerritoryCatalog.standard.territories.filter { $0.currencyCode == "EUR" && sheet.prices[$0.id] != nil }
        try #require(euro.count > 1)
        let shared = euro.dropFirst().reduce(Set(sheet.ladders[euro[0].id]?.points.map(\.customerPrice) ?? [])) { common, territory in
            common.intersection(sheet.ladders[territory.id]?.points.map(\.customerPrice) ?? [])
        }
        let currents = Set(euro.compactMap { sheet.prices[$0.id]?.current.customerPrice })
        let price = try #require(shared.subtracting(currents).sorted().first { $0 > 2 })

        let outcome = try await propose(["territories": "currency:EUR", "price": MCPPriceValue.json(price)])

        #expect(outcome.result["queued"] == .int(euro.count))
        #expect(changes.changes.count == euro.count)
        #expect(changes.changes.allSatisfy { $0.newValue == CurrencyFormat.forCurrency("EUR").format(price) })
    }

    @Test func onePriceForSeveralCurrenciesIsRefused() async throws {
        let outcome = try await propose(["territories": ["BRA", "DEU"], "price": 10])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("BRL") == true)
        #expect(changes.changes.isEmpty)
    }

    // MARK: - Suggestions

    @Test func acceptSuggestionsQueuesEachOpenSuggestion() async throws {
        let outcome = try await propose(["territories": "suggested", "acceptSuggestions": true])

        let results = try Fixtures.results(outcome)
        #expect(!results.isEmpty)
        #expect(results.values.allSatisfy { $0["status"] == "queued" })
        #expect(changes.change(id: Fixtures.changeID("BRA"))?.newValue == "R$ 109,90")
        #expect(changes.changes.allSatisfy { $0.source == .assistant(client: Fixtures.client) })
    }

    @Test func aCountryWithoutASuggestionIsUnchanged() async throws {
        let outcome = try await propose(["territory": "USA", "acceptSuggestions": true])
        #expect(outcome.result["status"] == "unchanged")
        #expect(outcome.result["note"]?.stringValue?.contains("no open suggestion") == true)
    }

    @Test func aDismissedCountryIsLeftOutOfSuggested() async throws {
        let modes = PricingModeStore(defaults: nil)
        modes.dismissCountrySuggestion(territoryID: "BRA", productID: Fixtures.annual, appID: Fixtures.lumen)

        let outcome = try await propose(["territories": "suggested", "acceptSuggestions": true], pricingModes: modes)

        #expect(try Fixtures.results(outcome)["BRA"] == nil)
        #expect(changes.change(id: Fixtures.changeID("BRA")) == nil)
    }

    @Test func exceptLeavesCountriesOut() async throws {
        let outcome = try await propose(["territories": "suggested", "except": ["BR"], "acceptSuggestions": true])
        #expect(try Fixtures.results(outcome)["BRA"] == nil)
        #expect(changes.change(id: Fixtures.changeID("BRA")) == nil)
    }

    // MARK: - Withdraw

    @Test func withdrawTakesBackOnlyYourOwn() async throws {
        _ = try await propose(["territory": "BRA", "price": .double(109.9)])
        try changes.upsert(Fixtures.personsChange("IND", to: "99"))

        let outcome = try await propose(["territories": ["BRA", "IND"], "withdraw": true])

        #expect(try status(outcome, "BRA") == "withdrawn")
        #expect(try status(outcome, "IND") == "unchanged")
        #expect(outcome.result["withdrawn"] == 1)
        #expect(changes.change(id: Fixtures.changeID("BRA")) == nil)
        #expect(changes.change(id: Fixtures.changeID("IND"))?.source == .you)
    }

    @Test func withdrawOneCountryAnswersForIt() async throws {
        _ = try await propose(["territory": "BRA", "price": .double(109.9)])
        let outcome = try await propose(["territory": "BRA", "withdraw": true])
        #expect(outcome.result["status"] == "withdrawn")
        #expect(outcome.result["territory"] == "BRA")
        #expect(changes.changes.isEmpty)
    }

    @Test func withdrawTakesYourVersionBesideThePersons() async throws {
        try changes.upsert(Fixtures.personsChange("BRA", to: "99.90"))
        _ = try await propose(["territory": "BRA", "price": .double(109.9)])
        #expect(changes.change(id: Fixtures.changeID("BRA"))?.alternative != nil)

        _ = try await propose(["territory": "BRA", "withdraw": true])

        let change = try #require(changes.change(id: Fixtures.changeID("BRA")))
        #expect(change.source == .you)
        #expect(change.alternative == nil)
    }

    @Test func withdrawOneCountryOfAnInAppPurchasesSchedule() async throws {
        let sheet = try Fixtures.sheet(Fixtures.lifetime)
        func lower(_ id: String) throws -> JSONValue {
            let current = try #require(sheet.prices[id]?.current.customerPrice)
            let point = try #require(sheet.ladders[id]?.points.last { $0.customerPrice < current * Decimal(9) / 10 })
            return MCPPriceValue.json(point.customerPrice)
        }
        let prices: [JSONValue] = try [["territory": "BRA", "price": lower("BRA")], ["territory": "IND", "price": lower("IND")]]
        _ = try await propose(["prices": .array(prices)], product: Fixtures.lifetime)

        let outcome = try await propose(["territory": "BRA", "withdraw": true], product: Fixtures.lifetime)

        #expect(outcome.result["status"] == "withdrawn")
        let change = try #require(changes.change(id: InAppPurchaseCountryPrices.changeID(productID: Fixtures.lifetime)))
        #expect(change.creation?.fields.map(\.id) == ["IND.price"])
    }

    @Test func keepMyPricesStillLetsYouWithdraw() async throws {
        let refused = try await propose(["appId": .string(Fixtures.tempo), "territories": "all", "automatic": true], product: "tempo.pro.annual")
        #expect(refused.result["status"] == "refused")
        let withdraw = try await propose(["appId": .string(Fixtures.tempo), "territory": "BRA", "withdraw": true], product: "tempo.pro.annual")
        #expect(withdraw.result["status"] == "unchanged")
    }

    // MARK: - Price point IDs

    @Test func aPricePointIDProposesItsPrice() async throws {
        let id = "debug-\(Fixtures.annual)-BRA-109.9"
        let outcome = try await propose(["territory": "BRA", "pricePointId": .string(id)])
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["price"] == .double(109.9))
        #expect(changes.change(id: Fixtures.changeID("BRA"))?.newValue == "R$ 109,90")
    }

    @Test func anUnknownPricePointIDIsRefused() async throws {
        let outcome = try await propose(["territory": "BRA", "pricePointId": "nope"])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("get_price_points") == true)
        #expect(changes.changes.isEmpty)
    }

    // MARK: - Unknown and arguments

    @Test func unknownCountriesAreRefusedBesideTheOthers() async throws {
        let outcome = try await propose(["territories": ["MEX", "Atlantis"], "automatic": true])
        #expect(try status(outcome, "Atlantis") == "refused")
        #expect(try status(outcome, "MEX") == "queued")
    }

    @Test func aSelectionThatMatchesNothingIsRefused() async throws {
        let outcome = try await propose(["territories": "currency:XYZ", "automatic": true])
        #expect(outcome.result["status"] == "refused")
    }

    @Test func territoriesTakeExactlyOneAction() async throws {
        await #expect(throws: MCPToolError.self) { try await propose(["territories": "all"]) }
        await #expect(throws: MCPToolError.self) { try await propose(["territories": "all", "automatic": true, "withdraw": true]) }
        await #expect(throws: MCPToolError.self) { try await propose(["territories": "all", "territory": "BRA", "automatic": true]) }
    }

    @Test func aSubscriptionsProposalWaitsUnderItsProductsRow() async throws {
        _ = try await propose(["territory": "BRA", "price": .double(109.9)])
        let change = try #require(changes.change(id: Fixtures.changeID("BRA")))
        #expect(change.creation?.id == PricesByCountryChanges.creationID(productID: Fixtures.annual))
        #expect(change.creation?.detail.contains("Brazil") == true)
    }
}
#endif
