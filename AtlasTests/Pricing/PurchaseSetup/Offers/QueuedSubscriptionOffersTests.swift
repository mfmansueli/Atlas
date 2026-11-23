//
//  QueuedSubscriptionOffersTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Promotional offers, win-back offers and offer codes for a new
/// subscription waiting in Review & Push: each its own change that names
/// the subscription by its placeholder and depends on the subscription's
/// change, so it's pushed after it, discarded with it and kept when the
/// subscription is edited; once the subscription is created, its ID goes
/// in.
@MainActor
@Suite("Offers for a queued subscription")
struct QueuedSubscriptionOffersTests {
    private static let app = NewSubscriptionChangeBuilderTests.app
    private let queue = ChangeQueue()

    /// The new subscription's change, queued, and the stand-in offers take.
    private func queuedSubscription() throws -> (change: PendingChange, subscription: PricingProduct) {
        let change = NewSubscriptionChangeBuilder(app: Self.app).change(for: NewSubscriptionChangeBuilderTests.monthly())
        queue.upsert(change)
        let target = try #require(PurchaseSetupTarget.queued(change))
        return try (change, #require(target.offerSubscription))
    }

    private var offers: SubscriptionOfferQueue {
        SubscriptionOfferQueue(app: Self.app, queue: queue)
    }

    @Test func theStandInNamesTheSubscriptionByItsPlaceholder() throws {
        let (_, subscription) = try queuedSubscription()
        #expect(subscription.id == "{queuedSubscription:com.lima.bruma.premium.monthly}")
        #expect(subscription.isQueuedSubscription)
        #expect(subscription.productID == "com.lima.bruma.premium.monthly")
        #expect(subscription.period == .oneMonth)
        #expect(subscription.basePrice == Decimal(string: "9.99"))
        #expect(!IntroductoryOfferChangeBuilderTests.monthly.isQueuedSubscription)
        #expect(PurchaseSetupTarget.existing(IntroductoryOfferChangeBuilderTests.monthly).offerSubscription?.id == "sub1")

        let placeholder = try #require(QueuedSubscriptionPlaceholder(token: subscription.id))
        #expect(placeholder.productID == "com.lima.bruma.premium.monthly")
        #expect(QueuedSubscriptionPlaceholder(token: "sub1") == nil)
        #expect(QueuedSubscriptionPlaceholder(token: "{queuedSubscription:}") == nil)
    }

    @Test func eachOfferDependsOnTheSubscriptionsChange() throws {
        let (subscriptionChange, subscription) = try queuedSubscription()
        let extras = PurchaseExtras(offersRead: true)
        let promotional = offers.queue(
            NewPromotionalOffer(name: "Come back", identifier: "come_back", terms: OfferTerms(mode: .freeTrial, duration: .oneWeek)),
            for: subscription, extras: extras, source: .you
        )
        let winBack = offers.queue(
            NewWinBackOffer(
                referenceName: "We miss you", offerID: "we_miss_you", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth),
                settings: WinBackOfferSettings(startDate: NewIntroductoryOffer.day(from: "2099-01-01") ?? .now)
            ),
            for: subscription, extras: extras, source: .you
        )
        var newCode = NewOfferCode(name: "Launch", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth))
        newCode.customCode = NewCustomCode(code: "LAUNCH", numberOfCodes: 100)
        let code = offers.queue(newCode, for: subscription, extras: extras, source: .you)

        for change in [promotional, winBack, code] {
            #expect(change.dependsOn == subscriptionChange.id)
            #expect(change.blockedReason == nil)
            #expect(change.groupID == subscription.id)
            #expect(change.requests.first.flatMap(SubscriptionOfferWrite.init)?.plan.subscriptionID == subscription.id)
        }
        #expect(offers.queued(for: subscription).count == 3)
        #expect(SubscriptionOfferChanges.waiting(for: subscriptionChange, in: queue).map(\.id).sorted() == [promotional, winBack, code].map(\.id).sorted())
        // An offer for a subscription App Store Connect has depends on nothing.
        let existing = offers.queue(
            NewPromotionalOffer(name: "Come back", identifier: "come_back", terms: OfferTerms(mode: .freeTrial, duration: .oneWeek)),
            for: IntroductoryOfferChangeBuilderTests.monthly, extras: extras, source: .you
        )
        #expect(existing.dependsOn == nil)
    }

    @Test func discardingTheSubscriptionDiscardsItsOffers() throws {
        let (subscriptionChange, subscription) = try queuedSubscription()
        offers.queue(
            NewPromotionalOffer(name: "Come back", identifier: "come_back", terms: OfferTerms(mode: .freeTrial, duration: .oneWeek)),
            for: subscription, extras: PurchaseExtras(offersRead: true), source: .you
        )
        #expect(queue.changes.count == 2)
        queue.discard(id: subscriptionChange.id)
        #expect(queue.changes.isEmpty)
    }

    @Test func editingTheSubscriptionKeepsItsOffers() throws {
        let (subscriptionChange, subscription) = try queuedSubscription()
        offers.queue(
            NewPromotionalOffer(name: "Come back", identifier: "come_back", terms: OfferTerms(mode: .freeTrial, duration: .oneWeek)),
            for: subscription, extras: PurchaseExtras(offersRead: true), source: .you
        )
        // An introductory offer is one more step of its change.
        let target = try #require(PurchaseSetupTarget.queued(subscriptionChange))
        PurchaseSetupQueue(app: Self.app, queue: queue).queueIntroductoryOffer(
            NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek), for: target, source: .you
        )
        #expect(queue.changes.count == 2)
        #expect(queue.change(id: subscriptionChange.id)?.requests != subscriptionChange.requests)
    }

    @Test func theCreatedSubscriptionsIDGoesIntoTheOffer() throws {
        let (_, subscription) = try queuedSubscription()
        let change = offers.queue(
            NewPromotionalOffer(
                name: "Half", identifier: "half",
                terms: OfferTerms(mode: .payUpFront, duration: .threeMonths, price: Decimal(string: "4.99"), territories: .chosen(["USA"]))
            ),
            for: subscription, extras: PurchaseExtras(offersRead: true), source: .you
        )
        let placeholder = try #require(QueuedSubscriptionPlaceholder(token: subscription.id))
        let request = try #require(change.requests.first)
        #expect(QueuedSubscriptionPlaceholder.first(in: request) == placeholder)

        let resolved = change.resolvingQueuedSubscription(placeholder, id: "sub9")
        #expect(resolved.dependsOn == nil)
        #expect(resolved.groupID == "sub9")
        let write = try #require(resolved.requests.first.flatMap(SubscriptionOfferWrite.init))
        #expect(write.plan.subscriptionID == "sub9")
        #expect(PushPagedRead.relationshipID("subscription", of: PushPagedRead.body(of: write.request)?["data"] as? [String: Any] ?? [:]) == "sub9")
        #expect(QueuedSubscriptionPlaceholder.first(in: write.request) == nil)
    }
}
