//
//  PriceTestFixtures.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Hand-built price tests and candidates for the board 76 tests.
enum PriceTestFixtures {
    static let today = PricingSampleData.date("2026-11-25")

    static func signal(_ pageViews: Int, _ starts: Int, proceeds: Decimal = 0) -> SalesSignal {
        SalesSignal(pageViews: pageViews, starts: starts, proceeds: proceeds)
    }

    /// A test in `region`, running from `startedOn` (nil: queued).
    static func test(
        id: String = "pt-1",
        region: TerritoryRegion = .europe,
        control: TerritoryRegion? = .asiaPacific,
        state: PriceTestState = .running,
        startedOn: Date? = PricingSampleData.date("2026-11-17"),
        countries: [PriceTestCountry] = [germany()],
        windows: PriceTestWindows? = nil
    ) -> PriceTest {
        PriceTest(
            id: id, productID: DebugPricingCatalog.lumenAnnualID, productName: "Lumen Plus Annual", region: region,
            step: .percent(-20), control: control, keepsTestPrice: true, countries: countries, state: state,
            sample: signal(2140, 96), createdAt: startedOn ?? today, startedOn: startedOn, windows: windows
        )
    }

    /// Germany €39.99 → €31.99.
    static func germany(old: String = "39.99", test: String = "31.99") -> PriceTestCountry {
        PriceTestCountry(
            territoryID: "DEU", currencyCode: "EUR", oldPrice: PricingFixtures.money(old), testPrice: PricingFixtures.money(test),
            oldPricePointID: "pp-old-DEU", testPricePointID: "pp-test-DEU"
        )
    }

    /// One country the planner can move, on a ladder of €1 steps.
    static func candidate(
        _ code: String,
        price: String = "40.00",
        suggested: String? = nil,
        recent: SalesSignal? = nil
    ) throws -> PriceTestCandidate {
        let territory = try PricingFixtures.territory(code)
        let prices = (20...60).map { "\($0).00" }
        let ladder = PricingFixtures.ladder(prices, currency: territory.currencyCode, territoryID: territory.id)
        let current = try #require(ladder.nearest(to: PricingFixtures.money(price)))
        let point = suggested.flatMap { ladder.nearest(to: PricingFixtures.money($0)) }
        return PriceTestCandidate(territory: territory, current: current, ladder: ladder, suggested: point, recent: recent)
    }

    /// The JSON bodies of a change's requests, in order.
    static func bodies(_ requests: [PushRequest]) throws -> [[String: Any]] {
        try requests.map { request in
            let data = try #require(request.body)
            let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            return try #require(object["data"] as? [String: Any])
        }
    }

    static func attributes(_ body: [String: Any]) -> [String: Any] {
        body["attributes"] as? [String: Any] ?? [:]
    }
}
