//
//  PricesByCountrySummaryTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: the Review & Push line")
struct PricesByCountrySummaryTests {
    private typealias Item = PricesByCountrySummary.Item

    @Test func namesEachCountryByName() {
        let text = PricesByCountrySummary.text([
            Item(name: "Japan", isAutomatic: true, price: ""),
            Item(name: "Brazil", isAutomatic: false, price: "R$ 199,90"),
        ])
        #expect(text == "Brazil R$ 199,90, Japan back to automatic. Applies when you push.")
    }

    @Test func countsTheRestPastThree() {
        let items = ["Brazil", "Chile", "India", "Japan", "Mexico"].map { Item(name: $0, isAutomatic: true, price: "") }
        let expected = "Brazil back to automatic, Chile back to automatic, India back to automatic, and 2 more. Applies when you push."
        #expect(PricesByCountrySummary.text(items) == expected)
    }

    @Test func fieldsReadBack() throws {
        let territory = try CountryPriceRowFixtures.territory("BRA")
        let field = PricesByCountryChanges.field(
            territory: territory, old: PricingFixtures.money("249.90"), new: PricingFixtures.money("199.90"), isAutomatic: false, source: .you
        )
        #expect(field.oldValue == "R$ 249,90")
        #expect(field.newValue == "R$ 199,90")
        #expect(PricesByCountryChanges.reading(field)?.territoryID == "BRA")
        #expect(PricesByCountryChanges.reading(field)?.isAutomatic == false)
    }
}
#endif
