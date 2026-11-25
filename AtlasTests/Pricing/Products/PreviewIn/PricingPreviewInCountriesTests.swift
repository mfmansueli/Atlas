//
//  PricingPreviewInCountriesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// "Preview in"'s countries: by name, with price changes first in the menu,
/// Find a country or currency, and ‹ › to the previous or next country with
/// a change.
@Suite("Preview in countries")
struct PricingPreviewInCountriesTests {
    /// Brazil and Japan change; Germany and the United States don't.
    private func countries(changed: Set<String> = ["BRA", "JPN"]) throws -> PricingPreviewInCountries {
        let territories = try ["USA", "JPN", "BRA", "DEU", "BRA"].map { id in
            try #require(TerritoryCatalog.standard.territory(alpha3: id))
        }
        return PricingPreviewInCountries(territories: territories, changedIDs: changed)
    }

    @Test func countriesAreListedOnceByName() throws {
        let countries = try countries()
        #expect(countries.countries.map(\.id) == ["BRA", "DEU", "JPN", "USA"])
        #expect(countries.count == 4)
        #expect(countries.changed.map(\.id) == ["BRA", "JPN"])
        #expect(countries.country(id: "JPN")?.hasChange == true)
        #expect(countries.country(id: "DEU")?.hasChange == false)
    }

    @Test func theMenuListsCountriesWithChangesFirstThenAll() throws {
        let groups = try countries().groups(matching: "")
        #expect(groups.map(\.kind) == [.withChanges, .all])
        #expect(groups.map(\.title) == ["With price changes", "All countries and regions"])
        #expect(groups[0].countries.map(\.id) == ["BRA", "JPN"])
        #expect(groups[1].countries.map(\.id) == ["BRA", "DEU", "JPN", "USA"])
    }

    @Test func withoutChangesThereIsOneGroup() throws {
        let groups = try countries(changed: []).groups(matching: "")
        #expect(groups.map(\.kind) == [.all])
    }

    @Test(arguments: [
        ("braz", ["BRA"]),
        ("BR", ["BRA"]),
        ("jpn", ["JPN"]),
        ("BRL", ["BRA"]),
        ("jpy", ["JPN"]),
        ("EUR", ["DEU"]),
        ("yen", ["JPN"]),
        (" united ", ["USA"]),
    ])
    func findMatchesNameCodeOrCurrency(query: String, expected: [String]) throws {
        #expect(try countries().matching(query).map(\.id) == expected)
    }

    @Test func findKeepsTheGroupsAndSaysHowManyMatch() throws {
        let countries = try countries()
        let groups = countries.groups(matching: "eur")
        #expect(groups.map(\.kind) == [.all], "Germany has no change, so only All countries and regions")
        #expect(countries.groups(matching: "jpy").map(\.kind) == [.withChanges, .all])
        #expect(countries.groups(matching: "zzz").isEmpty)
        #expect(countries.countText(matching: "") == "4")
        #expect(countries.countText(matching: "jpy") == "1 of 4")
    }

    @Test func nextAndPreviousGoThroughTheCountriesWithAChange() throws {
        let countries = try countries()
        #expect(countries.next(after: "BRA")?.id == "JPN")
        #expect(countries.next(after: "JPN")?.id == "BRA", "wraps around")
        #expect(countries.previous(before: "BRA")?.id == "JPN", "wraps around")
        #expect(countries.previous(before: "JPN")?.id == "BRA")
    }

    @Test func fromACountryWithoutAChangeTheyGoToTheNearestOneByName() throws {
        let countries = try countries()
        #expect(countries.next(after: "DEU")?.id == "JPN")
        #expect(countries.previous(before: "DEU")?.id == "BRA")
        #expect(countries.next(after: "USA")?.id == "BRA", "nothing after the United States: back to the first")
        #expect(countries.previous(before: "USA")?.id == "JPN")
        #expect(countries.next(after: "XXX")?.id == "BRA")
        #expect(countries.previous(before: "XXX")?.id == "JPN")
    }

    @Test func withNoChangeThereIsNowhereToGo() throws {
        let countries = try countries(changed: [])
        #expect(countries.next(after: "BRA") == nil)
        #expect(countries.previous(before: "BRA") == nil)
        let one = try self.countries(changed: ["BRA"])
        #expect(one.next(after: "BRA")?.id == "BRA", "the only one: the arrows are disabled")
    }
}
