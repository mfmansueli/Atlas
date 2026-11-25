//
//  MCPCountrySelectionTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Country selection for the price tools")
struct MCPCountrySelectionTests {
    /// Lumen Plus Annual's countries, as the price tools read them.
    private func rows() async throws -> [CountryPriceRow] {
        let catalog = try await MCPPriceCatalog.load(app: MCPPricingFixtures.lumen, in: MCPTestFixtures.workspace())
        return try await catalog.sheet(for: catalog.requireProduct(MCPPricingFixtures.annual)).countryRows()
    }

    @Test(arguments: [
        ("all", MCPCountrySelection.Item.all),
        ("Europe", .region(.europe)),
        ("region:asiaPacific", .region(.asiaPacific)),
        ("Asia Pacific", .region(.asiaPacific)),
        ("currency:eur", .currency("EUR")),
        ("suggested", .source(.suggested)),
        ("Set by you", .source(.setByYou)),
        ("BRA", .territory("BRA")),
        ("Brazil", .territory("Brazil")),
    ])
    func itemsAreRead(text: String, item: MCPCountrySelection.Item) {
        #expect(MCPCountrySelection.item(text) == item)
    }

    @Test func groupsCombineOnceInCatalogOrder() async throws {
        let rows = try await rows()
        let selection = MCPCountrySelection(items: [.territory("MEX"), .region(.americas), .territory("br")])
        let resolved = selection.resolve(in: rows)
        let americas = rows.filter { $0.territory.region == .americas }.map(\.id)
        #expect(resolved.rows.map(\.id) == americas)
        #expect(resolved.unknown.isEmpty)
    }

    @Test func exceptAndUnknownItems() async throws {
        let resolved = try await MCPCountrySelection(items: [.currency("EUR"), .territory("Atlantis")], except: ["DE"]).resolve(in: rows())
        #expect(!resolved.rows.contains { $0.id == "DEU" })
        #expect(resolved.rows.allSatisfy { $0.territory.currencyCode == "EUR" })
        #expect(resolved.unknown == ["Atlantis"])
    }

    @Test func setByYouLeavesTheBaseOut() async throws {
        let resolved = try await MCPCountrySelection(items: [.source(.setByYou)]).resolve(in: rows())
        #expect(!resolved.rows.isEmpty)
        #expect(!resolved.rows.contains { $0.isBase })
        #expect(resolved.rows.contains { $0.id == "MEX" })
    }

    @Test func parsesAStringOrAList() throws {
        let one = try MCPCountrySelection.parse(MCPToolArguments(["territories": "europe", "except": ["GBR"]]))
        #expect(one == MCPCountrySelection(items: [.region(.europe)], except: ["GBR"]))
        let none = try MCPCountrySelection.parse(MCPToolArguments([:]))
        #expect(none == nil)
        #expect(throws: MCPToolError.self) { try MCPCountrySelection.parse(MCPToolArguments(["territories": .array([])])) }
        #expect(throws: MCPToolError.self) { try MCPCountrySelection.parse(MCPToolArguments(["territories": 3])) }
    }
}
#endif
