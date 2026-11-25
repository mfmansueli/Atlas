//
//  PricesByCountryQueryTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: filter, find and sort")
struct PricesByCountryQueryTests {
    private typealias Fixtures = CountryPriceRowFixtures

    private func ids(_ rows: [CountryPriceRow]) -> [String] { rows.map(\.id) }

    @Test func eachFilterListsItsRows() throws {
        let rows = try Fixtures.sample()
        let visible = { (filter: PricesByCountryFilter) in
            ids(PricesByCountryQuery.visible(rows, filter: filter, search: "", sortOrder: []))
        }
        #expect(visible(.all) == ["USA", "BRA", "DEU", "JPN", "MEX"])
        #expect(visible(.suggested) == ["BRA"])
        #expect(visible(.setByYou) == ["USA", "DEU"])
        #expect(visible(.automatic) == ["BRA", "JPN", "MEX"])
    }

    @Test func findMatchesNameCodeCurrencyAndRegion() throws {
        let rows = try Fixtures.sample()
        let found = { (text: String) in ids(PricesByCountryQuery.visible(rows, filter: .all, search: text, sortOrder: [])) }
        #expect(found("braz") == ["BRA"])
        #expect(found("JP") == ["JPN"])
        #expect(found("mex") == ["MEX"])
        #expect(found("EUR") == ["DEU"])
        #expect(found(" ") == ["USA", "BRA", "DEU", "JPN", "MEX"])
        #expect(found("Atlantis").isEmpty)
    }

    @Test func countsFollowTheFindField() throws {
        let rows = try Fixtures.sample()
        let all = PricesByCountryQuery.counts(rows, search: "")
        #expect(all == [.all: 5, .suggested: 1, .setByYou: 2, .automatic: 3])
        let found = PricesByCountryQuery.counts(rows, search: "brazil")
        #expect(found == [.all: 1, .suggested: 1, .setByYou: 0, .automatic: 1])
    }

    @Test func withoutASortTheBaseComesFirstThenByName() throws {
        let rows = try Fixtures.sample().reversed()
        #expect(ids(PricesByCountryQuery.sorted(Array(rows), by: [])) == ["USA", "BRA", "DEU", "JPN", "MEX"])
    }

    @Test func sortsByCountryDollarsAndChange() throws {
        let rows = try Fixtures.sample()
        let byName = PricesByCountryQuery.sorted(rows, by: [KeyPathComparator(\CountryPriceRow.name, order: .reverse)])
        #expect(ids(byName) == ["USA", "MEX", "JPN", "DEU", "BRA"])

        let byDollars = PricesByCountryQuery.sorted(rows, by: [KeyPathComparator(\CountryPriceRow.dollarsSortKey, order: .reverse)])
        #expect(byDollars.first?.id == "DEU" || byDollars.first?.id == "USA")
        #expect(byDollars.map(\.dollarsSortKey) == byDollars.map(\.dollarsSortKey).sorted(by: >))

        // The biggest drop first; rows without a change last.
        let byChange = PricesByCountryQuery.sorted(rows, by: [KeyPathComparator(\CountryPriceRow.changeSortKey)])
        #expect(ids(byChange).prefix(2) == ["BRA", "MEX"])
        #expect(byChange.suffix(3).allSatisfy { $0.changeSortKey == CountryPriceRow.noChangeSortKey })
    }
}
#endif
