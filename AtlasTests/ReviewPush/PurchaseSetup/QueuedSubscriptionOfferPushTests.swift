//
//  QueuedSubscriptionOfferPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Offers proposed for a new subscription waiting in Review & Push: the
/// push creates the subscription first, then the offers with its ID; when
/// the subscription isn't created, they wait in the queue.
@MainActor
@Suite("PushController · offers for a queued subscription")
struct QueuedSubscriptionOfferPushTests {
    private let queue = ChangeQueue()
    private let history = PushHistory()
    private static let app = NewSubscriptionChangeBuilderTests.app

    private static func created(_ type: String, _ id: String) -> Data {
        Data(#"{"data":{"type":"\#(type)","id":"\#(id)"}}"#.utf8)
    }

    /// App Store Connect as a new subscription's steps meet it: it becomes `sub9`.
    private static var transport: FakePushTransport {
        FakePushTransport(
            remote: [
                "/v1/subscriptions/sub9/versions?limit=200": Data(#"{"data":[{"id":"sv1","attributes":{"version":1,"state":"PREPARE_FOR_SUBMISSION"}}]}"#.utf8),
                SubscriptionAvailabilityEverywhere.territoriesPath: Data(#"{"data":[{"id":"USA"},{"id":"BRA"}]}"#.utf8),
                "/v1/subscriptions/sub9/pricePoints?filter%5Bterritory%5D=USA&fields%5BsubscriptionPricePoints%5D=customerPrice&limit=8000":
                    Data(#"{"data":[{"id":"p2","attributes":{"customerPrice":"9.99"}}]}"#.utf8),
            ],
            responses: [
                "/v1/subscriptionGroups": created("subscriptionGroups", "grp9"),
                "/v1/subscriptions": created("subscriptions", "sub9"),
                "/v1/subscriptionGroupVersions": created("subscriptionGroupVersions", "gv1"),
                "/v1/subscriptionAvailabilities": created("subscriptionAvailabilities", "av1"),
                SubscriptionOfferResource.offerCode.path: created("subscriptionOfferCodes", "oc9"),
                NewCustomCode.path: created("subscriptionOfferCodeCustomCodes", "cc9"),
            ]
        )
    }

    /// The new subscription's change and an offer code with a custom code
    /// for it, both queued (the offer code first, as an assistant might).
    private func queueSubscriptionWithOfferCode() throws -> (subscription: PendingChange, code: PendingChange) {
        let subscription = NewSubscriptionChangeBuilder(app: Self.app).change(for: NewSubscriptionChangeBuilderTests.monthly())
        let standIn = try #require(PurchaseSetupTarget.queued(subscription)?.offerSubscription)
        var code = NewOfferCode(name: "Launch", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth, territories: .chosen(["USA"])))
        code.customCode = NewCustomCode(code: "LAUNCH", numberOfCodes: 100)
        let offer = OfferCodeChangeBuilder(app: Self.app).change(for: code, subscription: standIn)
        queue.upsert(offer)
        queue.upsert(subscription)
        return (subscription, offer)
    }

    @Test func theOfferGoesOutAfterTheSubscriptionWithItsID() async throws {
        let (subscription, code) = try queueSubscriptionWithOfferCode()
        let transport = Self.transport
        let controller = PushController(queue: queue, history: history, transport: transport)
        controller.push(queue.changes)
        await controller.waitUntilFinished()

        #expect(controller.items.map(\.id) == [subscription.id, code.id])
        #expect(controller.doneCount == 2)
        #expect(queue.changes.isEmpty)
        let paths = transport.sent.map(\.path)
        let subscriptionCreate = try #require(paths.firstIndex(of: NewSubscriptionCreate.path))
        let offerCreate = try #require(paths.firstIndex(of: SubscriptionOfferResource.offerCode.path))
        #expect(subscriptionCreate < offerCreate)
        let data = try #require(PushPagedRead.body(of: transport.sent[offerCreate])?["data"] as? [String: Any])
        #expect(PushPagedRead.relationshipID("subscription", of: data) == "sub9")
        #expect(transport.fetched.contains(SubscriptionOfferResource.offerCode.identitiesPath(subscriptionID: "sub9")))
        #expect(transport.sent.allSatisfy { QueuedSubscriptionPlaceholder.first(in: $0) == nil })
        // Its custom code went to the offer code it created.
        let custom = try #require(transport.sent.first { $0.path == NewCustomCode.path })
        #expect(PushPagedRead.relationshipID("offerCode", of: PushPagedRead.body(of: custom)?["data"] as? [String: Any] ?? [:]) == "oc9")
    }

    @Test func anOfferWhoseSubscriptionIsntCreatedWaits() async throws {
        let (subscription, code) = try queueSubscriptionWithOfferCode()
        // Apple refuses the subscription.
        let rejected = AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR", detail: "No")
        let transport = FakePushTransport(createFailures: [NewSubscriptionCreate.path: rejected])
        let controller = PushController(queue: queue, history: history, transport: transport)
        controller.push(queue.changes)
        await controller.waitUntilFinished()

        #expect(controller.doneCount == 0)
        let offer = try #require(controller.items.first { $0.id == code.id })
        #expect(offer.status == .notSent(QueuedSubscriptionPlaceholder.NotCreated(productID: "com.lima.bruma.premium.monthly").errorDescription ?? ""))
        #expect(!transport.sent.contains { $0.path == SubscriptionOfferResource.offerCode.path })
        // Both stay, the offer still waiting for the subscription.
        #expect(queue.change(id: subscription.id) != nil)
        #expect(queue.change(id: code.id)?.dependsOn == subscription.id)
    }

    @Test func anOfferWaitsWhenItsSubscriptionIsntInThePush() async throws {
        let (subscription, code) = try queueSubscriptionWithOfferCode()
        let transport = Self.transport
        let controller = PushController(queue: queue, history: history, transport: transport)
        controller.push(queue.changes.filter { $0.id != subscription.id })
        await controller.waitUntilFinished()
        #expect(controller.items.first?.status.isFailure == false)
        #expect(transport.sent.isEmpty)
        #expect(queue.change(id: code.id) != nil)
    }
}
