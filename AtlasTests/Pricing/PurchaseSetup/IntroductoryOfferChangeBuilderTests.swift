//
//  IntroductoryOfferChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An introductory offer in Review & Push: its own change for a
/// subscription App Store Connect has, or one more step of a new
/// subscription's change, with the request the push expands per territory.
@MainActor
@Suite("IntroductoryOfferChangeBuilder")
struct IntroductoryOfferChangeBuilderTests {
    static let app = NewSubscriptionChangeBuilderTests.app
    static let monthly = PricingProduct(
        id: "sub1", name: "Bruma Premium Monthly", productID: "com.lima.bruma.premium.monthly", period: .oneMonth,
        isInAppPurchase: false, reviewState: "Approved", basePrice: Decimal(string: "9.99")
    )
    static let paid = NewIntroductoryOffer(
        mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3, price: Decimal(string: "4.99"), territories: .chosen(["USA", "BRA"])
    )

    private func data(_ request: PushRequest) throws -> [String: Any] {
        let body = try #require(PushPagedRead.body(of: request))
        return try #require(body["data"] as? [String: Any])
    }

    @Test func anExistingSubscriptionsOfferIsItsOwnChange() throws {
        let change = IntroductoryOfferChangeBuilder(app: Self.app).change(
            for: Self.paid, subscription: Self.monthly, source: .assistant(client: "Claude Code"), evidence: ["Paywall.swift:40"]
        )
        #expect(change.id == IntroductoryOfferChangeBuilder.changeID(appID: "app1", productID: "com.lima.bruma.premium.monthly"))
        #expect(IntroductoryOfferChangeBuilder.owns(change))
        #expect(PurchaseSetupQueue.isSetup(change))
        #expect(change.section == .subscriptionPricing)
        #expect(change.blockedReason == nil)
        #expect(change.requests.count == 1)
        #expect(change.creation?.fields.contains { $0.id == "evidence" } == true)

        let step = try #require(IntroductoryOfferEverywhere(change.requests[0]))
        #expect(step.subscriptionID == "sub1")
        #expect(step.offer == Self.paid)
        #expect(IntroductoryOfferChangeBuilder.offer(in: change) == Self.paid)
    }

    @Test func theQueuedRequestCarriesTheTermsAsAppleTakesThem() throws {
        var offer = Self.paid
        offer.startDate = NewIntroductoryOffer.day(from: "2026-12-01")
        let request = IntroductoryOfferEverywhere(subscriptionID: "sub1", offer: offer).request
        #expect(request.method == .post)
        #expect(request.path == "/v1/subscriptionIntroductoryOffers")
        let data = try data(request)
        #expect(data["type"] as? String == "subscriptionIntroductoryOffers")
        let attributes = try #require(data["attributes"] as? [String: Any])
        #expect(attributes["offerMode"] as? String == "PAY_AS_YOU_GO")
        #expect(attributes["duration"] as? String == "ONE_MONTH")
        #expect(attributes["numberOfPeriods"] as? Int == 3)
        #expect(attributes["startDate"] as? String == "2026-12-01")
        #expect(attributes["endDate"] == nil)
        #expect(PushPagedRead.relationshipID("subscription", of: data) == "sub1")
        #expect(PushPagedRead.relationshipID("territory", of: data) == IntroductoryOfferEverywhere.placeholder)

        // One territory's POST, as the push sends it.
        let sent = try self.data(IntroductoryOfferEverywhere(subscriptionID: "sub1", offer: offer).request(territoryID: "BRA", pricePointID: "pp-bra"))
        #expect(PushPagedRead.relationshipID("territory", of: sent) == "BRA")
        #expect(PushPagedRead.relationshipID("subscriptionPricePoint", of: sent) == "pp-bra")
        let sentBody = PushPagedRead.body(of: IntroductoryOfferEverywhere(subscriptionID: "sub1", offer: offer).request(territoryID: "BRA", pricePointID: nil))
        #expect(sentBody?["atlas"] == nil)
    }

    @Test func aFreeTrialSendsNoPricePoint() throws {
        let trial = NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek)
        let step = IntroductoryOfferEverywhere(subscriptionID: "sub1", offer: trial)
        let data = try data(step.request(territoryID: "USA", pricePointID: nil))
        #expect(PushPagedRead.relationshipID("subscriptionPricePoint", of: data) == nil)
        #expect((data["attributes"] as? [String: Any])?["numberOfPeriods"] as? Int == 1)
        #expect(IntroductoryOfferEverywhere(step.request)?.offer.territories == .everywhere)
    }

    @Test func aNewSubscriptionCarriesItsOfferAfterItsPrices() throws {
        let builder = NewSubscriptionChangeBuilder(app: Self.app)
        let created = builder.change(for: NewSubscriptionChangeBuilderTests.monthly())
        let attached = IntroductoryOfferChangeBuilder.attaching(Self.paid, to: created, source: .you)

        #expect(attached.id == created.id)
        #expect(attached.source == created.source)
        #expect(attached.requests.count == created.requests.count + 1)
        let step = try #require(attached.requests.last.flatMap(IntroductoryOfferEverywhere.init))
        #expect(step.subscriptionID == "{createdID:subscriptions}")
        #expect(attached.creation?.fields.contains { $0.id == IntroductoryOfferChangeBuilder.fieldID } == true)

        // Changing it replaces the step; detaching removes it.
        let trial = NewIntroductoryOffer(mode: .freeTrial, duration: .twoWeeks)
        let changed = IntroductoryOfferChangeBuilder.attaching(trial, to: attached, source: .you)
        #expect(changed.requests.count == attached.requests.count)
        #expect(IntroductoryOfferChangeBuilder.offer(in: changed) == trial)
        #expect(changed.creation?.fields.count { $0.id == IntroductoryOfferChangeBuilder.fieldID } == 1)
        #expect(IntroductoryOfferChangeBuilder.detaching(from: changed).requests == created.requests)
    }

    @Test func proposingTheSubscriptionAgainKeepsItsOffer() {
        let builder = NewSubscriptionChangeBuilder(app: Self.app)
        let created = builder.change(for: NewSubscriptionChangeBuilderTests.monthly())
        let attached = IntroductoryOfferChangeBuilder.attaching(Self.paid, to: created, source: .you)
        var cheaper = NewSubscriptionChangeBuilderTests.monthly()
        cheaper.price = Decimal(string: "7.99")
        let again = PurchaseSetupQueue.carryingExtras(from: attached, into: builder.change(for: cheaper))
        #expect(IntroductoryOfferChangeBuilder.offer(in: again) == Self.paid)
        #expect(again.creation?.fields.contains { $0.id == IntroductoryOfferChangeBuilder.fieldID } == true)
        #expect(PurchaseSetupQueue.carryingExtras(from: nil, into: created) == created)
    }

    @Test func theQueueAttachesToAQueuedSubscriptionOrMakesAChange() throws {
        let queue = ChangeQueue()
        let setup = PurchaseSetupQueue(app: Self.app, queue: queue)
        let created = NewSubscriptionChangeBuilder(app: Self.app).change(for: NewSubscriptionChangeBuilderTests.monthly())
        queue.upsert(created)

        let queued = try #require(PurchaseSetupTarget.queued(created))
        #expect(queued.period == .oneMonth)
        #expect(queued.usPrice == Decimal(string: "9.99"))
        #expect(setup.queueIntroductoryOffer(Self.paid, for: queued, source: .assistant(client: "Claude Code")) == created.id)
        #expect(queue.changes.count == 1)
        // Still the person's change, not an alternative of it.
        #expect(queue.change(id: created.id)?.source == .you)
        #expect(queue.change(id: created.id)?.alternative == nil)
        #expect(setup.queuedIntroductoryOffer(for: queued) == Self.paid)

        let existing = PurchaseSetupTarget.existing(Self.monthly)
        let id = try #require(setup.queueIntroductoryOffer(Self.paid, for: existing, source: .you))
        #expect(queue.changes.count == 2)
        #expect(setup.queuedIntroductoryOffer(for: existing) == Self.paid)
        #expect(id == IntroductoryOfferChangeBuilder.changeID(appID: "app1", productID: Self.monthly.productID))
    }
}
