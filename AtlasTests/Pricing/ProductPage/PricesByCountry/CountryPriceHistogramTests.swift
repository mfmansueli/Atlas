//
//  CountryPriceHistogramTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: the histogram")
struct CountryPriceHistogramTests {
    private typealias Fixtures = CountryPriceRowFixtures

    @Test func countsCountriesPerFiveDollars() throws {
        let rows = try [
            Fixtures.row("USA", current: "3"),
            Fixtures.row("USA", current: "7", suggestion: "4"),
            Fixtures.row("USA", current: "12"),
        ]
        let histogram = CountryPriceHistogram(rows: rows, basePrice: 7, baseCurrency: "USD")
        let now = histogram.bins.filter { $0.series == .now }
        #expect(now.map(\.lowerBound) == [0, 5, 10])
        #expect(now.map(\.count) == [1, 1, 1])
        let suggested = histogram.bins.filter { $0.series == .suggested }
        #expect(suggested.map(\.count) == [2, 0, 1])
        #expect(histogram.hasSuggestions)
        #expect(histogram.baseDollars == 7)
        #expect(histogram.maximumCount == 2)
        #expect(now.first?.label == "$0–5")
    }

    @Test func withoutSuggestionsOnlyTodaysBarsShow() throws {
        let histogram = try CountryPriceHistogram(rows: [Fixtures.row("USA", current: "9.99")], basePrice: nil, baseCurrency: "USD")
        #expect(!histogram.hasSuggestions)
        #expect(histogram.bins.allSatisfy { $0.series == .now })
        #expect(histogram.baseDollars == nil)
    }
}
#endif
