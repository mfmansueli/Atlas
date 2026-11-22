//
//  PushControllerConcurrencyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A push sends several changes at once (`PushSchedule.concurrentChanges`), and those that depend on each
/// other still one after the other.
@MainActor
@Suite("PushController · several at once")
struct PushControllerConcurrencyTests {
    private let queue = ChangeQueue()

    private func push(_ changes: [PendingChange], via transport: SlowPushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    private func listing(_ locale: String) -> PendingChange {
        PendingChange(
            id: "listing.\(locale).whatsNew", appID: "lumen", section: .storePage, group: "Store Page", title: locale,
            oldValue: "old", newValue: "new",
            requests: [PushRequest(method: .patch, path: "/v1/appStoreVersionLocalizations/\(locale)")]
        )
    }

    private static let locales = (1...12).map { "l\($0)" }

    @Test func plainTextEditsGoSeveralAtATime() async {
        let transport = SlowPushTransport()
        let controller = await push(Self.locales.map(listing), via: transport)

        #expect(transport.mostInFlight == PushSchedule.concurrentChanges)
        #expect(controller.doneCount == Self.locales.count)
        #expect(queue.changes.isEmpty)
    }

    @Test func pricesOfOneAppStillGoOneByOneBesideTheTexts() async {
        let transport = SlowPushTransport()
        let prices = ["BRA", "MEX", "CHL"].map { PushFixtures.price($0) }
        _ = await push(prices + ["de", "en"].map(listing), via: transport)

        #expect(!transport.overlapped("/v1/subscriptionPrices/BRA", "/v1/subscriptionPrices/MEX"))
        #expect(!transport.overlapped("/v1/subscriptionPrices/MEX", "/v1/subscriptionPrices/CHL"))
        let order = transport.started.filter { $0.hasPrefix("/v1/subscriptionPrices") }
        #expect(order == ["/v1/subscriptionPrices/BRA", "/v1/subscriptionPrices/MEX", "/v1/subscriptionPrices/CHL"])
        #expect(transport.overlapped("/v1/subscriptionPrices/BRA", "/v1/appStoreVersionLocalizations/de"))
    }

    /// Prices as `PriceChangeFactory` writes them, one per territory, go
    /// several at once like the texts.
    @Test func pricesInManyTerritoriesGoSeveralAtATime() async throws {
        let transport = SlowPushTransport()
        let prices = try (1...12).map { index in
            let body = SubscriptionPriceCreateRequest(subscriptionID: "annual", territoryID: "T\(index)", pricePointID: "pp\(index)")
            return try PendingChange(
                id: "price.annual.T\(index)", appID: "lumen", section: .subscriptionPricing, group: "Subscription Pricing", title: "T\(index)",
                oldValue: "old", newValue: "new", requests: [PushRequest.json(.post, "/v1/subscriptionPrices", body)]
            )
        }
        let controller = await push(prices, via: transport)

        #expect(transport.mostInFlight == PushSchedule.concurrentChanges)
        #expect(controller.doneCount == prices.count)
        #expect(queue.changes.isEmpty)
    }

    @Test func cancellingLetsTheOnesInFlightFinishAndLeavesTheRest() async {
        let transport = SlowPushTransport(delay: .milliseconds(80))
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        queue.upsert(contentsOf: Self.locales.map(listing))
        controller.push(queue.changes)
        try? await Task.sleep(for: .milliseconds(20))
        controller.cancelRemaining()
        await controller.waitUntilFinished()

        let left = Self.locales.count - PushSchedule.concurrentChanges
        #expect(controller.doneCount == PushSchedule.concurrentChanges)
        #expect(controller.items.count { $0.status == .notSent("Cancelled") } == left)
        #expect(queue.changes.count == left)
    }
}
