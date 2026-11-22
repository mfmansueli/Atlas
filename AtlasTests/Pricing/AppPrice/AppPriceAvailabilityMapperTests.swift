//
//  AppPriceAvailabilityMapperTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Apple's price schedule, price points, availability and territories as
/// Pricing reads them.
@Suite("App price and availability reads")
struct AppPriceAvailabilityMapperTests {
    private static func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private static func price(_ id: String, territory: String, point: String, start: String? = nil, end: String? = nil) -> String {
        let dates = [start.map { #""startDate":"\#($0)""# }, end.map { #""endDate":"\#($0)""# }].compactMap(\.self).joined(separator: ",")
        return #"""
        {"type":"appPrices","id":"\#(id)","attributes":{"manual":true\#(dates.isEmpty ? "" : ",")\#(dates)},
         "relationships":{"territory":{"data":{"type":"territories","id":"\#(territory)"}},
                          "appPricePoint":{"data":{"type":"appPricePoints","id":"\#(point)"}}}}
        """#
    }

    private static func point(_ id: String, price: String, proceeds: String) -> String {
        #"{"type":"appPricePoints","id":"\#(id)","attributes":{"customerPrice":"\#(price)","proceeds":"\#(proceeds)"}}"#
    }

    @Test func todaysBasePriceWinsAndTheRestIsCounted() throws {
        let json = """
        {"data":[
          \(Self.price("a", territory: "USA", point: "p099", end: "2026-11-01")),
          \(Self.price("b", territory: "USA", point: "p299", start: "2026-11-01")),
          \(Self.price("c", territory: "USA", point: "p499", start: "2026-12-01")),
          \(Self.price("d", territory: "BRA", point: "pbr"))
         ],
         "included":[
          \(Self.point("p099", price: "0.99", proceeds: "0.84")),
          \(Self.point("p299", price: "2.99", proceeds: "2.54")),
          \(Self.point("p499", price: "4.99", proceeds: "4.24")),
          \(Self.point("pbr", price: "14.90", proceeds: "10.13")),
          {"type":"territories","id":"USA","attributes":{"currency":"USD"}}
         ]}
        """
        let document: PricingAPIDocument<AppPriceAttributes> = try Self.decode(json)
        let current = AppPriceAvailabilityMapper.currentPrice(scheduleID: "s1", baseTerritoryID: "USA", prices: document, today: "2026-11-22")

        #expect(current.point?.customerPrice == Decimal(string: "2.99"))
        #expect(current.point?.proceeds == Decimal(string: "2.54"))
        #expect(current.point?.appStoreConnectID == "p299")
        #expect(current.currencyCode == "USD")
        #expect(current.otherManualTerritoryIDs == ["BRA"])
        #expect(current.laterChangeCount == 1)
        #expect(current.formattedPrice == "$2.99")
        #expect(current.replacesMoreThanThePrice)
    }

    @Test func aFreeAppReadsFree() throws {
        let json = """
        {"data":[\(Self.price("a", territory: "USA", point: "p0"))],
         "included":[\(Self.point("p0", price: "0.0", proceeds: "0.0"))]}
        """
        let document: PricingAPIDocument<AppPriceAttributes> = try Self.decode(json)
        let current = AppPriceAvailabilityMapper.currentPrice(scheduleID: "s1", baseTerritoryID: "USA", prices: document, today: "2026-11-22")
        #expect(current.isFree)
        #expect(current.formattedPrice == "Free")
        #expect(!current.replacesMoreThanThePrice)
        #expect(AppPriceState.set(current).current != nil)
    }

    @Test func pricePointsAreOneTerritorysLadder() throws {
        let json = #"""
        {"data":[
          {"type":"appPricePoints","id":"q2","attributes":{"customerPrice":"0.99","proceeds":"0.84"},
           "relationships":{"territory":{"data":{"type":"territories","id":"USA"}}}},
          {"type":"appPricePoints","id":"q1","attributes":{"customerPrice":"0.0","proceeds":"0.0"},
           "relationships":{"territory":{"data":{"type":"territories","id":"USA"}}}}
         ],
         "included":[{"type":"territories","id":"USA","attributes":{"currency":"USD"}}]}
        """#
        let document: PricingAPIDocument<SubscriptionPricePointAttributes> = try Self.decode(json)
        let ladder = AppPriceAvailabilityMapper.ladder(document, territoryID: "USA")
        #expect(ladder.currencyCode == "USD")
        #expect(ladder.points.map(\.customerPrice) == [0, Decimal(string: "0.99")])
        #expect(ladder.points.map(\.appStoreConnectID) == ["q1", "q2"])
    }

    @Test func availabilityHasEveryTerritoryByName() throws {
        let json = #"""
        {"data":[
          {"type":"territoryAvailabilities","id":"t1","attributes":{"available":true,"releaseDate":"2026-12-20","preOrderEnabled":true},
           "relationships":{"territory":{"data":{"type":"territories","id":"USA"}}}},
          {"type":"territoryAvailabilities","id":"t2","attributes":{"available":false,"contentStatuses":["ICP_NUMBER_MISSING"]},
           "relationships":{"territory":{"data":{"type":"territories","id":"CHN"}}}},
          {"type":"territoryAvailabilities","id":"t3","attributes":{"available":true},
           "relationships":{"territory":{"data":{"type":"territories","id":"BRA"}}}}
         ]}
        """#
        let page: AppStoreConnectLinkedPage<TerritoryAvailabilityAttributes> = try Self.decode(json)
        let availability = AppPriceAvailabilityMapper.availability(id: "av1", availableInNewTerritories: true, territories: page.data)

        #expect(availability.territories.map(\.territoryID) == ["BRA", "CHN", "USA"])
        #expect(availability.availableCount == 2)
        #expect(availability.territory("CHN")?.id == "t2")
        #expect(availability.territory("CHN")?.contentStatuses == ["ICP_NUMBER_MISSING"])
        #expect(availability.preOrderReleaseDate == "2026-12-20")
    }

    @Test func territoriesAreApplesWithTheirCurrency() throws {
        let json = #"{"data":[{"type":"territories","id":"USA","attributes":{"currency":"USD"}},"#
            + #"{"type":"territories","id":"BRA","attributes":{"currency":"BRL"}}]}"#
        let page: AppStoreConnectPage<TerritoryAttributes> = try Self.decode(json)
        let territories = AppPriceAvailabilityMapper.territories(page.data)
        #expect(territories.map(\.id) == ["BRA", "USA"])
        #expect(territories.first?.currencyCode == "BRL")
        #expect(territories.first?.name == "Brazil")
    }
}
