//
//  LivePricingServicesLaddersTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Apple's price point ladders read from App Store Connect: in batches of
/// 25 territories, once per product (a second caller finds the first one's),
/// from the cache after that, with the commission's proceeds.
@MainActor
@Suite("Pricing · Apple's price point ladders")
struct LivePricingServicesLaddersTests {
    private let annual = PricingProduct(
        id: "s1", name: "Lumen Plus Annual", productID: "lumen.annual", period: .oneYear, isInAppPurchase: false, reviewState: "Approved"
    )

    /// One point in each territory: R$ 9,90-like prices, proceeds 70% and
    /// proceedsYear2 85%.
    private static func points(_ territoryIDs: [String]) -> CannedHTTPResponse {
        let data = territoryIDs.map { id in
            #"""
            {"type":"subscriptionPricePoints","id":"p-\#(id)","attributes":{"customerPrice":"9.99","proceeds":"6.99","proceedsYear2":"8.49"},
            "relationships":{"territory":{"data":{"type":"territories","id":"\#(id)"}}}}
            """#
        }
        return CannedHTTPResponse(body: #"{"data":[\#(data.joined(separator: ","))]}"#)
    }

    private static let territoryIDs = Array(TerritoryCatalog.standard.territories.map(\.id).prefix(30))

    private func services() -> (LivePricingServices, FakeHTTPTransport) {
        let transport = FakeHTTPTransport([], routes: [("/v1/subscriptions/s1/pricePoints", Self.points(Self.territoryIDs))])
        let services = LivePricingServices(
            client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport),
            cache: LivePricingCache(directory: nil)
        )
        return (services, transport)
    }

    private func pointRequests(_ transport: FakeHTTPTransport) -> [URLRequest] {
        transport.requests.filter { $0.url?.path() == "/v1/subscriptions/s1/pricePoints" }
    }

    @Test func territoriesGoInBatchesOf25WithoutRepeats() {
        let ids = (0..<60).map { "T\($0)" }
        let batches = LivePricingServices.batches(ids + ["T0", "T1"])
        #expect(batches.map(\.count) == [25, 25, 10])
        #expect(batches.flatMap(\.self) == ids)
        #expect(LivePricingServices.batches([]).isEmpty)
    }

    @Test func thirtyTerritoriesTakeTwoReads() async throws {
        let (services, transport) = services()
        let ladders = try await services.ladders(for: annual, territoryIDs: Self.territoryIDs, commission: .standard)
        #expect(ladders.count == 30)
        #expect(pointRequests(transport).count == 2)
        let filters = pointRequests(transport).compactMap { request -> String? in
            guard let url = request.url else { return nil }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "filter[territory]" }?.value
        }
        #expect(filters.map { $0.split(separator: ",").count } == [25, 5])
    }

    @Test func theSecondReadComesFromTheCache() async throws {
        let (services, transport) = services()
        _ = try await services.ladders(for: annual, territoryIDs: Self.territoryIDs, commission: .standard)
        let before = pointRequests(transport).count
        let again = try await services.ladders(for: annual, territoryIDs: Array(Self.territoryIDs.prefix(10)), commission: .standard)
        #expect(again.count == 10)
        #expect(pointRequests(transport).count == before)
    }

    @Test func anotherCommissionReadsAgain() async throws {
        let (services, transport) = services()
        _ = try await services.ladders(for: annual, territoryIDs: ["BRA"], commission: .standard)
        _ = try await services.ladders(for: annual, territoryIDs: ["BRA"], commission: .smallBusiness)
        #expect(pointRequests(transport).count == 2)
    }

    @Test func twoCallersAtOnceReadOnce() async throws {
        let (services, transport) = services()
        async let first = services.ladders(for: annual, territoryIDs: Self.territoryIDs, commission: .standard)
        async let second = services.ladders(for: annual, territoryIDs: Self.territoryIDs, commission: .standard)
        let (one, two) = try await (first, second)
        #expect(one.count == 30)
        #expect(two.count == 30)
        // One read's two batches; the second caller waited and found them.
        #expect(pointRequests(transport).count == 2)
    }

    @Test func proceedsFollowTheCommission() async throws {
        let (services, _) = services()
        let small = try await services.ladders(for: annual, territoryIDs: ["BRA"], commission: .smallBusiness)
        let standard = try await services.ladders(for: annual, territoryIDs: ["BRA"], commission: .standard)
        // Small Business Program: the after-one-year rate from the start.
        #expect(small["BRA"]?.points.first?.proceeds == PricingFixtures.money("8.49"))
        #expect(standard["BRA"]?.points.first?.proceeds == PricingFixtures.money("6.99"))
        #expect(standard["BRA"]?.points.first?.appStoreConnectID == "p-BRA")
    }

    @Test func aPushDropsTheProductsLadders() async throws {
        let (services, transport) = services()
        _ = try await services.ladders(for: annual, territoryIDs: ["BRA"], commission: .standard)
        await services.forgetLadders(for: annual.id, fetchedBefore: Date().addingTimeInterval(60))
        _ = try await services.ladders(for: annual, territoryIDs: ["BRA"], commission: .standard)
        #expect(pointRequests(transport).count == 2)
    }

    @Test func aFailedReadKeepsTheBatchesThatArrived() async throws {
        let transport = FakeHTTPTransport([], routes: [
            ("filter[territory]=\(Self.territoryIDs.prefix(25).joined(separator: ","))", Self.points(Array(Self.territoryIDs.prefix(25)))),
            ("/v1/subscriptions/s1/pricePoints", CannedHTTPResponse(statusCode: 404, body: #"{"errors":[{"status":"404","code":"NOT_FOUND"}]}"#)),
        ])
        let services = LivePricingServices(
            client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport),
            cache: LivePricingCache(directory: nil)
        )
        await #expect(throws: (any Error).self) {
            try await services.ladders(for: annual, territoryIDs: Self.territoryIDs, commission: .standard)
        }
        let kept = await services.cache.ladders(for: annual.id, commission: .standard, territoryIDs: Self.territoryIDs)
        #expect(kept.count == 25)
    }

    @Test func aPriceSheetUsesTheCachedLadders() async {
        var sheet = ProductPriceSheet(
            productID: "s1",
            baseTerritoryID: "USA",
            basePrice: PricingFixtures.money("9.99"),
            prices: ["BRA": TerritoryPrice(
                territoryID: "BRA",
                current: PricePoint(customerPrice: PricingFixtures.money("9.99"), proceeds: 0),
                equalized: PricePoint(customerPrice: PricingFixtures.money("9.99"), proceeds: 0),
                equalizationMultiplier: 1
            )]
        )
        #expect(!sheet.hasRealGrid("BRA"))
        let cache = LivePricingCache(directory: nil)
        cache.store(["BRA": PricePointLadder(territoryID: "BRA", currencyCode: "BRL", points: [
            PricePoint(customerPrice: PricingFixtures.money("9.99"), proceeds: PricingFixtures.money("8.49"), appStoreConnectID: "p-BRA"),
        ])], for: "s1", commission: .smallBusiness)
        await sheet.merge(cache.ladders(for: "s1", commission: .smallBusiness, territoryIDs: sheet.prices.keys))
        #expect(sheet.hasRealGrid("BRA"))
        #expect(sheet.prices["BRA"]?.current.appStoreConnectID == "p-BRA")
    }
}
