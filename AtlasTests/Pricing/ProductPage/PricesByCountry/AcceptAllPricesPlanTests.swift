//
//  AcceptAllPricesPlanTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: Accept All")
struct AcceptAllPricesPlanTests {
    private typealias Fixtures = CountryPriceRowFixtures

    @Test func countsWhatGoesDownAndUpWithTheBiggestMovesFirst() throws {
        let rows = try [
            Fixtures.row("BRA", current: "249.90", suggestion: "129.90"),
            Fixtures.row("IND", current: "3299", suggestion: "1499"),
            Fixtures.row("MEX", current: "799", suggestion: "699"),
            Fixtures.row("IDN", current: "649000", suggestion: "349000"),
            Fixtures.row("CHE", current: "39", suggestion: "45"),
            Fixtures.row("JPN", current: "6800"),
        ]
        let plan = AcceptAllPricesPlan(rows: rows)
        #expect(plan.downCount == 4)
        #expect(plan.upCount == 1)
        #expect(plan.count == 5)
        #expect(plan.hasIncreases)
        #expect(plan.downExamples.count == AcceptAllPricesPlan.exampleCount)
        #expect(plan.downExamples.first?.id == "IND")
        #expect(plan.upExamples.map(\.id) == ["CHE"])
        #expect(plan.downTitle == "4 go down")
        #expect(plan.upTitle == "1 goes up")
    }

    @Test func theExampleShowsBothPrices() throws {
        let plan = try AcceptAllPricesPlan(rows: [Fixtures.row("BRA", current: "249.90", suggestion: "129.90")])
        #expect(plan.downExamples.first?.prices == "R$ 249,90 → R$ 129,90")
        #expect(!plan.hasIncreases)
    }
}
#endif
