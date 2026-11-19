//
//  InAppPurchasePricesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// In-app purchase prices read from App Store Connect. Pricing used to
/// throw "couldn't find that resource. Prices for in-app purchases aren't
/// shown yet." for each of SimProps's four purchases, as an error.
@MainActor
@Suite("Pricing · in-app purchase prices")
struct InAppPurchasePricesTests {
    private let pro = PricingProduct(id: "iap1", name: "SimProps Pro", productID: "com.SimProps.pro", isInAppPurchase: true, reviewState: "Ready to Submit")

    private static func json(_ text: String) -> CannedHTTPResponse {
        CannedHTTPResponse(statusCode: 200, body: text)
    }

    private static let schedule = schedule(id: "sched1")

    private static func schedule(id: String) -> CannedHTTPResponse {
        json(#"""
        {"data":{"type":"inAppPurchasePriceSchedules","id":"\#(id)",
        "relationships":{"baseTerritory":{"data":{"type":"territories","id":"USA"}}}},
        "included":[{"type":"territories","id":"USA","attributes":{"currency":"USD"}}]}
        """#)
    }

    private static func price(_ id: String, territory: String, point: String, start: String? = nil, end: String? = nil, manual: Bool) -> String {
        let start = start.map { #""\#($0)""# } ?? "null"
        let end = end.map { #""\#($0)""# } ?? "null"
        return #"""
        {"type":"inAppPurchasePrices","id":"\#(id)","attributes":{"startDate":\#(start),"endDate":\#(end),"manual":\#(manual)},
        "relationships":{"inAppPurchasePricePoint":{"data":{"type":"inAppPurchasePricePoints","id":"\#(point)"}},
        "territory":{"data":{"type":"territories","id":"\#(territory)"}}}}
        """#
    }

    private static func point(_ id: String, _ price: String, _ proceeds: String, territory: String? = nil) -> String {
        let relationships = territory.map { #","relationships":{"territory":{"data":{"type":"territories","id":"\#($0)"}}}"# } ?? ""
        return #"{"type":"inAppPurchasePricePoints","id":"\#(id)","attributes":{"customerPrice":"\#(price)","proceeds":"\#(proceeds)"}\#(relationships)}"#
    }

    private static func list(_ data: [String], included: [String] = []) -> CannedHTTPResponse {
        json(#"{"data":[\#(data.joined(separator: ","))],"included":[\#(included.joined(separator: ","))]}"#)
    }

    /// The US price set by hand ($4.99, an older $2.99 ended), Brazil set by
    /// hand below Apple's equalized price, Great Britain equalized by Apple
    /// (its price changed in June).
    private static let manual = list(
        [
            price("m1", territory: "USA", point: "p-usa-old", end: "2026-03-01", manual: true),
            price("m2", territory: "USA", point: "p-usa", start: "2026-03-01", manual: true),
            price("m3", territory: "BRA", point: "p-bra-custom", manual: true),
        ],
        included: [point("p-usa-old", "2.99", "2.09"), point("p-usa", "4.99", "3.49"), point("p-bra-custom", "19.90", "12.00")]
    )
    private static let automatic = list(
        [
            price("a1", territory: "BRA", point: "p-bra", manual: false),
            price("a2", territory: "GBR", point: "p-gbr-old", end: "2026-06-01", manual: false),
            price("a3", territory: "GBR", point: "p-gbr", start: "2026-06-01", manual: false),
            price("a4", territory: "DEU", point: "p-deu-next", start: "2027-01-01", manual: false),
        ],
        included: [point("p-bra", "29.90", "18.00"), point("p-gbr-old", "4.49", "3.00"), point("p-gbr", "4.99", "3.33"), point("p-deu-next", "5.99", "3.50")]
    )
    private static let equalizations = list([point("e-bra", "29.90", "18.00", territory: "BRA"), point("e-gbr", "4.99", "3.33", territory: "GBR")])

    private func services(_ routes: [(text: String, response: CannedHTTPResponse)]) -> (LivePricingServices, FakeHTTPTransport) {
        let transport = FakeHTTPTransport([], routes: routes)
        var services = LivePricingServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
        services.today = { Date(timeIntervalSince1970: 1_794_960_000) } // 2026-11-18
        return (services, transport)
    }

    @Test func todaysPriceInEveryTerritoryIsRead() async throws {
        let (services, transport) = services([
            ("iapPriceSchedule", Self.schedule), ("manualPrices", Self.manual), ("automaticPrices", Self.automatic),
            ("p-usa/equalizations", Self.equalizations),
        ])
        let sheet = try await services.priceSheet(for: pro, commission: .standard)
        #expect(sheet.baseTerritoryID == "USA")
        #expect(sheet.basePrice == Decimal(string: "4.99"))
        #expect(sheet.prices["USA"]?.current.proceeds == Decimal(string: "3.49"))
        // Set by hand: kept over Apple's automatic price, and custom.
        #expect(sheet.prices["BRA"]?.current.customerPrice == Decimal(string: "19.90"))
        #expect(sheet.prices["BRA"]?.equalized.customerPrice == Decimal(string: "29.90"))
        #expect(sheet.prices["BRA"]?.isCustom == true)
        // Apple's, today's: not the one that ended, not one still to come.
        #expect(sheet.prices["GBR"]?.current.customerPrice == Decimal(string: "4.99"))
        #expect(sheet.prices["GBR"]?.isCustom == false)
        #expect(sheet.prices["DEU"] == nil)
        let paths = transport.requests.compactMap { $0.url?.path() }
        #expect(paths.contains("/v2/inAppPurchases/iap1/iapPriceSchedule"))
        #expect(paths.contains("/v1/inAppPurchasePriceSchedules/sched1/manualPrices"))
        #expect(paths.contains("/v1/inAppPurchasePriceSchedules/sched1/automaticPrices"))
    }

    /// SimProps's 7-day Trial: Price Tier 0, free everywhere.
    @Test func aFreeTrialIsFreeEverywhere() async throws {
        let (services, _) = services([
            ("iapPriceSchedule", Self.schedule),
            ("manualPrices", Self.list([Self.price("m1", territory: "USA", point: "p0", manual: true)], included: [Self.point("p0", "0.0", "0.0")])),
            ("automaticPrices", Self.list(
                [Self.price("a1", territory: "BRA", point: "p0-bra", manual: false)], included: [Self.point("p0-bra", "0.0", "0.0")]
            )),
            ("equalizations", Self.list([Self.point("e0", "0.0", "0.0", territory: "BRA")])),
        ])
        var trial = pro
        trial.name = "7-day Trial"
        let sheet = try await services.priceSheet(for: trial, commission: .smallBusiness)
        #expect(sheet.basePrice == 0)
        #expect(sheet.prices["BRA"]?.current.customerPrice == 0)
        #expect(sheet.prices["BRA"]?.equalizationMultiplier == 1)
    }

    @Test func aPurchaseWithoutAPriceSaysSoInsteadOfFailing() async {
        let missing = CannedHTTPResponse(statusCode: 404, body: #"{"errors":[{"status":"404","code":"NOT_FOUND","title":"Not found","detail":"None."}]}"#)
        let (never, _) = services([("iapPriceSchedule", missing)])
        await #expect(throws: PricingSheetError.noInAppPurchasePrice(productName: "SimProps Pro")) {
            try await never.priceSheet(for: pro, commission: .standard)
        }
        let (empty, _) = services([("iapPriceSchedule", Self.schedule), ("manualPrices", Self.list([])), ("automaticPrices", Self.list([]))])
        await #expect(throws: PricingSheetError.noInAppPurchasePrice(productName: "SimProps Pro")) {
            try await empty.priceSheet(for: pro, commission: .standard)
        }
        #expect(!PricingSheetError.noInAppPurchasePrice(productName: "SimProps Pro").offersStartingPrice)
    }

    /// Apple's proceeds are the account's own rate already: SimProps Pro,
    /// a Small Business Program member, $29.99 → $25.49 (85%). Scaling them
    /// again showed $30.95, more than the price.
    @Test func applesProceedsAreShownAsTheyAre() throws {
        for commission in Commission.allCases {
            let point = try #require(LivePricingMapper.inAppPurchasePricePoint(id: "p", customerPrice: "29.99", proceeds: "25.49", commission: commission))
            #expect(point.customerPrice == Decimal(string: "29.99"))
            #expect(point.proceeds == Decimal(string: "25.49"))
        }
    }

    /// The Overview's Subscriptions card showed “—” for each in-app purchase,
    /// and SimProps, with no subscriptions, had no territory numbers.
    @Test func theOverviewShowsInAppPurchasePrices() async throws {
        let purchases = Self.json(#"""
        {"data":[
        {"type":"inAppPurchases","id":"trial",
        "attributes":{"name":"7-day Trial","productId":"com.SimProps.trial","inAppPurchaseType":"NON_CONSUMABLE","state":"APPROVED"}},
        {"type":"inAppPurchases","id":"pro",
        "attributes":{"name":"SimProps Pro","productId":"com.SimProps.pro","inAppPurchaseType":"NON_CONSUMABLE","state":"APPROVED"}}
        ]}
        """#)
        let (services, transport) = services([
            ("subscriptionGroups", Self.json(#"{"data":[]}"#)),
            ("inAppPurchasesV2", purchases),
            ("inAppPurchases/trial/iapPriceSchedule", Self.schedule(id: "sched-trial")),
            ("inAppPurchases/pro/iapPriceSchedule", Self.schedule(id: "sched-pro")),
            ("sched-trial/manualPrices", Self.list(
                [Self.price("m0", territory: "USA", point: "p0", manual: true)], included: [Self.point("p0", "0.0", "0.0")]
            )),
            ("sched-pro/manualPrices", Self.list(
                [Self.price("m1", territory: "USA", point: "p-pro", manual: true)], included: [Self.point("p-pro", "29.99", "25.49")]
            )),
            ("sched-pro/automaticPrices", Self.list(
                [Self.price("a1", territory: "BRA", point: "p-pro-bra", manual: false)], included: [Self.point("p-pro-bra", "149.90", "110.00")]
            )),
            ("p-pro/equalizations", Self.list([Self.point("e-bra", "149.90", "110.00", territory: "BRA")])),
        ])
        let app = StoreApp(id: "6825503090", name: "SimProps", bundleID: "com.SimProps", primaryLocale: "en-US")
        let summary = try await services.summary(for: app)
        let pro = try CurrencyFormat.format(#require(Decimal(string: "29.99")), currency: "USD")
        #expect(summary.products.map(\.basePrice) == ["Free", pro])
        // The free trial isn't what the territory numbers describe.
        #expect(summary.reportedProductName == "SimProps Pro")
        #expect(summary.equalizedTerritoryCount + summary.customTerritoryCount == 2)
        // The catalog reads only the base territory's price.
        let filtered = transport.requests.compactMap(\.url).filter { $0.path().hasSuffix("/manualPrices") && $0.query()?.contains("USA") == true }
        #expect(filtered.count >= 2)
    }

    @Test func laddersComeFromTheInAppPurchasesPricePoints() async throws {
        let points = Self.list([Self.point("l1", "0.99", "0.69", territory: "BRA"), Self.point("l2", "1.99", "1.39", territory: "BRA")])
        let (services, transport) = services([("/v2/inAppPurchases/iap1/pricePoints", points)])
        let ladders = try await services.ladders(for: pro, territoryIDs: ["BRA"], commission: .standard)
        #expect(ladders["BRA"]?.points.count == 2)
        #expect(transport.requests.first?.url?.path() == "/v2/inAppPurchases/iap1/pricePoints")
    }

    #if DEBUG
    @Test func aPurchaseWithoutAPriceIsNoFailureOnTheScreen() async {
        var debug = DebugPricingServices()
        debug.sheetError = .noInAppPurchasePrice(productName: "Lumen Lifetime")
        let model = PricingViewModel(
            app: PricingModelFixtures.app, services: debug, queue: ChangeQueue(), modes: PricingModeStore(defaults: nil), commission: .smallBusiness
        )
        await model.load()
        #expect(model.hasNoPrice)
        #expect(!model.needsStartingPrice)
        #expect(model.sheetError == "Lumen Lifetime has no price yet. Set it in App Store Connect.")
        await model.loadProducts()
        #expect(model.productErrors.values.allSatisfy { $0 == "No price yet. Set it in App Store Connect." })
    }
    #endif
}
