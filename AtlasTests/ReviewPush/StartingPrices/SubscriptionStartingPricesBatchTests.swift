//
//  SubscriptionStartingPricesBatchTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A subscription's starting price in every territory: a few batched
/// `PATCH`es with inline prices, or, when App Store Connect refuses one, one
/// `POST` per territory left, a few at once; "Prices · N of M" either way.
@MainActor
@Suite("Starting prices · batches and the fallback")
struct SubscriptionStartingPricesBatchTests {
    private let prices = SubscriptionStartingPrices(
        SubscriptionStartingPrices.request(subscriptionID: StartingPricesTransport.subscriptionID, territoryID: "USA", price: Decimal(string: "9.99") ?? 0)
    )

    private static let refusal = AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR.INCLUDED.INVALID", detail: "Not allowed.")

    private func object(_ request: PushRequest) -> [String: Any] {
        request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
    }

    private func included(_ request: PushRequest) -> [[String: Any]] {
        object(request)["included"] as? [[String: Any]] ?? []
    }

    private func related(_ resource: [String: Any], _ name: String) -> String? {
        let relationships = resource["relationships"] as? [String: Any]
        return ((relationships?[name] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String
    }

    /// Each batch's territories, in order.
    private func territories(of request: PushRequest) -> [String] {
        included(request).compactMap { related($0, "territory") }
    }

    /// Sends them, returning the refusal and every (set, total) reported.
    private func send(
        via transport: StartingPricesTransport,
        batches: Bool = true
    ) async throws -> (refusal: AppStoreConnectError?, progress: [[Int]]) {
        let prices = try #require(prices)
        var progress: [[Int]] = []
        let refusal = try await prices.send(via: transport, slots: PushSlots(), batches: batches) { set, total in
            progress.append([set, total])
        } note: { _ in }
        return (refusal, progress)
    }

    // MARK: - The batched write

    @Test func aBatchIsOnePatchOfTheSubscriptionWithInlinePrices() throws {
        let prices = try #require(prices)
        let request = prices.batch([
            .init(territoryID: "USA", pricePointID: "p2"),
            .init(territoryID: "BRA", pricePointID: "e1"),
        ])

        #expect(request.method == .patch)
        #expect(request.path == "/v1/subscriptions/sub1")
        let data = try #require(object(request)["data"] as? [String: Any])
        #expect(data["type"] as? String == "subscriptions")
        #expect(data["id"] as? String == "sub1")
        let links = ((data["relationships"] as? [String: Any])?["prices"] as? [String: Any])?["data"] as? [[String: Any]] ?? []
        #expect(links.compactMap { $0["id"] as? String } == ["${price1}", "${price2}"])
        #expect(links.allSatisfy { $0["type"] as? String == "subscriptionPrices" })

        let inline = included(request)
        #expect(inline.compactMap { $0["id"] as? String } == ["${price1}", "${price2}"])
        #expect(inline.allSatisfy { $0["type"] as? String == "subscriptionPrices" })
        #expect(inline.allSatisfy { ($0["attributes"] as? [String: Any])?["preserveCurrentPrice"] as? Bool == false })
        #expect(inline.compactMap { related($0, "territory") } == ["USA", "BRA"])
        #expect(inline.compactMap { related($0, "subscriptionPricePoint") } == ["p2", "e1"])
        #expect(inline.compactMap { related($0, "subscription") } == ["sub1", "sub1"])
    }

    @Test func onlyApplesRefusalsOfTheBatchFallBack() {
        #expect(SubscriptionStartingPrices.isBatchRefusal(Self.refusal))
        #expect(SubscriptionStartingPrices.isBatchRefusal(AppStoreConnectError.server(statusCode: 400, detail: nil)))
        #expect(!SubscriptionStartingPrices.isBatchRefusal(AppStoreConnectError.rateLimited))
        #expect(!SubscriptionStartingPrices.isBatchRefusal(AppStoreConnectError.unauthorized))
        #expect(!SubscriptionStartingPrices.isBatchRefusal(AppStoreConnectError.server(statusCode: 500, detail: nil)))
        #expect(!SubscriptionStartingPrices.isBatchRefusal(URLError(.timedOut)))
    }

    // MARK: - Sending

    /// 175 territories (the US and 174 equalized) in four `PATCH`es.
    @Test func everyTerritoryGoesInPatchesOfFifty() async throws {
        let transport = StartingPricesTransport()
        let result = try await send(via: transport)

        #expect(result.refusal == nil)
        #expect(transport.posts.isEmpty)
        #expect(transport.patches.map { included($0).count } == [50, 50, 50, 25])
        let sent = transport.patches.flatMap(territories(of:))
        #expect(sent.first == "USA")
        #expect(Set(sent).count == 175)
        #expect(result.progress == [[50, 175], [100, 175], [150, 175], [175, 175]])
    }

    @Test func territoriesWithAPriceAreLeftAlone() async throws {
        let transport = StartingPricesTransport(territories: 3, priced: ["T002"])
        _ = try await send(via: transport)

        #expect(transport.patches.flatMap(territories(of:)) == ["USA", "T001", "T003"])
    }

    @Test func nothingIsSentWhenEveryTerritoryHasAPrice() async throws {
        let transport = StartingPricesTransport(territories: 1, priced: ["USA", "T001"])
        let result = try await send(via: transport)

        #expect(transport.sent.isEmpty)
        #expect(result.progress.isEmpty)
    }

    /// Refused: one `POST` per territory, never more than the push's
    /// requests at once, and the progress still counts to 175.
    @Test func aRefusedBatchFallsBackToOnePostPerTerritoryAFewAtOnce() async throws {
        let transport = StartingPricesTransport(patchFailure: Self.refusal)
        let result = try await send(via: transport)

        #expect(result.refusal == Self.refusal)
        #expect(transport.patches.count == 1)
        #expect(transport.posts.count == 175)
        #expect(transport.posts.allSatisfy { $0.path == "/v1/subscriptionPrices" })
        #expect(Set(transport.posts.compactMap { SubscriptionStartingPricesBatchTests.postTerritory($0) }).count == 175)
        #expect(transport.mostInFlight > 1)
        #expect(transport.mostInFlight <= PushSchedule.concurrentRequests)
        #expect(result.progress.count == 175)
        #expect(result.progress.map { $0[0] } == Array(1...175))
        #expect(result.progress.allSatisfy { $0[1] == 175 })
    }

    /// The first batch went through: only the territories after it are posted.
    @Test func aRefusalAfterABatchPostsOnlyWhatsLeft() async throws {
        let transport = StartingPricesTransport(patchFailure: Self.refusal, failingPatch: 2)
        let result = try await send(via: transport)

        #expect(result.refusal == Self.refusal)
        let batched = try #require(transport.patches.first.map(territories(of:)))
        #expect(batched.count == 50)
        let posted = Set(transport.posts.compactMap { SubscriptionStartingPricesBatchTests.postTerritory($0) })
        #expect(posted.count == 125)
        #expect(posted.isDisjoint(with: batched))
        #expect(result.progress.first == [50, 175])
        #expect(result.progress.last == [175, 175])
    }

    /// Out of requests or offline isn't a refusal of the batch: the push
    /// stops as for any request.
    @Test func aRateLimitedBatchStopsInsteadOfFallingBack() async throws {
        let transport = StartingPricesTransport(patchFailure: AppStoreConnectError.rateLimited)
        let prices = try #require(prices)
        do {
            try await prices.send(via: transport, slots: PushSlots()) { _, _ in } note: { _ in }
            Issue.record("Expected the rate limit")
        } catch {
            #expect(error as? AppStoreConnectError == .rateLimited)
        }
        #expect(transport.posts.isEmpty)
    }

    /// After a refusal earlier in the push the batch isn't tried again.
    @Test func withoutBatchesEveryTerritoryIsPostedAtOnce() async throws {
        let transport = StartingPricesTransport(territories: 20)
        let result = try await send(via: transport, batches: false)

        #expect(result.refusal == nil)
        #expect(transport.patches.isEmpty)
        #expect(transport.posts.count == 21)
        #expect(result.progress.last == [21, 21])
    }

    /// A `POST`'s territory.
    private static func postTerritory(_ request: PushRequest) -> String? {
        guard let body = request.body, let document = try? JSONDecoder().decode(SubscriptionPriceCreateRequest.self, from: body) else { return nil }
        return document.data.relationships.territory.data.id
    }
}
