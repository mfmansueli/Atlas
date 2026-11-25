//
//  CountryPriceMapTileTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@Suite("Prices by Country: the map")
struct CountryPriceMapTileTests {
    private typealias Fixtures = CountryPriceRowFixtures

    private let feels = CountryFeelsLike(
        multiplier: Decimal(string: "5.4") ?? 0, factor: Decimal(string: "0.56") ?? 0, basePrice: Decimal(string: "39.99") ?? 0, baseCurrency: "USD"
    )

    @Test func aTileShowsItsCodeRatioAndRing() throws {
        let row = try Fixtures.row("BRA", current: "249.90", suggestion: "129.90", feelsLike: feels)
        let now = try #require(CountryPriceMapTile.tiles([row], showsSuggested: false).first)
        #expect(now.code == "BR")
        #expect(now.ratioText == "2.1×")
        #expect(now.level == .muchPricier)
        #expect(now.hasSuggestion)
        let suggested = try #require(CountryPriceMapTile.tiles([row], showsSuggested: true).first)
        #expect(suggested.ratioText == "1.1×")
        #expect(suggested.level == .aboutTheSame)
    }

    @Test func tilesGroupByRegion() throws {
        let tiles = try CountryPriceMapTile.tiles(Fixtures.sample(), showsSuggested: false)
        let groups = CountryPriceMapTile.grouped(tiles)
        #expect(groups.map(\.region) == [.americas, .europe, .asiaPacific])
        #expect(groups.first?.tiles.map(\.id) == ["BRA", "MEX", "USA"])
    }
}
#endif
