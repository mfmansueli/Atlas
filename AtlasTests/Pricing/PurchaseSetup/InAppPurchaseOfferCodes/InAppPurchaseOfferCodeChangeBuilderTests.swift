//
//  InAppPurchaseOfferCodeChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An in-app purchase's offer codes as Review & Push changes: the create
/// with its plan and codes, codes for an offer code App Store Connect has,
/// and deactivations that check it's still active first.
@Suite("InAppPurchaseOfferCodeChangeBuilder")
struct InAppPurchaseOfferCodeChangeBuilderTests {
    static let app = NewSubscriptionChangeBuilderTests.app
    static let lifetime = PricingProduct(
        id: "iap1", name: "Bruma Lifetime", productID: "com.lima.bruma.lifetime",
        isInAppPurchase: true, reviewState: "Approved", basePrice: Decimal(string: "79.99")
    )
    static let existing = ExistingInAppPurchaseOfferCode(
        id: "ioc1", name: "Launch week", eligibilities: [.nonSpender],
        customCodes: [ExistingCustomCode(id: "cc1", code: "BRUMALIFE", numberOfCodes: 100)],
        oneTimeCodes: [ExistingOneTimeCodes(id: "ot1", numberOfCodes: 50, expirationDate: "2099-01-01", createdDate: "2026-11-02")]
    )

    private let builder = InAppPurchaseOfferCodeChangeBuilder(app: Self.app)
    private let expiry = NewIntroductoryOffer.day(from: "2099-01-01") ?? .now

    @Test func aNewOfferCodeIsOneChangeWithItsCodes() throws {
        var code = NewInAppPurchaseOfferCode(
            name: "Launch week", eligibilities: [.churnedSpender, .nonSpender],
            terms: InAppPurchaseOfferTerms(price: Decimal(string: "39.99"), territories: .chosen(["USA", "BRA"]))
        )
        code.customCode = NewCustomCode(code: "BRUMALIFE", numberOfCodes: 100)
        code.oneTimeCodes = NewOneTimeCodes(numberOfCodes: 50, expirationDate: expiry)
        let change = builder.change(for: code, purchase: Self.lifetime)

        #expect(change.id == "iapOfferCode.\(Self.app.id).com.lima.bruma.lifetime.launch_week")
        #expect(InAppPurchaseOfferCodeChangeBuilder.owns(change))
        #expect(SubscriptionOfferChanges.owns(change))
        #expect(SubscriptionOfferChanges.kind(of: change) == .offerCode)
        #expect(change.section == .subscriptionPricing)
        #expect(change.groupID == "iap1")
        #expect(change.requests.map(\.path) == [
            InAppPurchaseOfferCodeResource.offerCodesPath, InAppPurchaseOfferCodeResource.customCodesPath,
            InAppPurchaseOfferCodeResource.oneTimeCodesPath,
        ])
        #expect(change.creation != nil)
        let plan = try #require(InAppPurchaseOfferCodeWrite(change.requests[0])?.plan)
        #expect(plan.owner == .inAppPurchase("iap1"))
        #expect(plan.usPrice == Decimal(string: "39.99"))
        #expect(plan.territoryIDs == ["USA", "BRA"])

        // It reads back as the offer code it makes.
        let back = try #require(InAppPurchaseOfferCodeChangeBuilder.offerCode(in: change))
        #expect(back.trimmedName == "Launch week")
        #expect(back.eligibilities == [.nonSpender, .churnedSpender])
        #expect(back.terms.price == Decimal(string: "39.99"))
        #expect(back.customCode?.code == "BRUMALIFE")
        #expect(back.oneTimeCodes?.numberOfCodes == 50)
        #expect(InAppPurchaseOfferCodeChangeBuilder.customCodes(in: change).map(\.code) == ["BRUMALIFE"])
        // The codes wait for the offer code the push creates.
        #expect(InAppPurchaseCustomCodeCreate(change.requests[1])?.offerCodeID == PushRequest.createdIDPlaceholder(type: "inAppPurchaseOfferCodes"))
    }

    @Test func aPlanForAnInAppPurchaseSurvivesTheQueue() throws {
        let plan = OfferPricesPlan(owner: .inAppPurchase("iap1"), usPrice: 0, territoryIDs: nil, territoryPrices: [:])
        let back = try #require(OfferPricesPlan(body: [OfferPricesPlan.metaKey: [OfferPricesPlan.planKey: plan.json]]))
        #expect(back.owner == .inAppPurchase("iap1"))
        #expect(back.usPrice == 0)
        #expect(plan.json["inAppPurchaseID"] as? String == "iap1")
        // A subscription's keeps its own key.
        let subscription = OfferPricesPlan(subscriptionID: "sub1", usPrice: nil, territoryIDs: nil)
        #expect(subscription.json["subscriptionID"] as? String == "sub1")
        #expect(OfferPricesPlan(body: [OfferPricesPlan.metaKey: [OfferPricesPlan.planKey: subscription.json]])?.owner == .subscription("sub1"))
    }

    @Test func codesForAnExistingOfferCodeAreTheirOwnChanges() throws {
        let custom = builder.customCodeChange(NewCustomCode(code: "newcode", numberOfCodes: 10), for: Self.existing, purchase: Self.lifetime)
        #expect(custom.id == "iapOfferCode.\(Self.app.id).com.lima.bruma.lifetime.ioc1.custom.NEWCODE")
        #expect(InAppPurchaseCustomCodeCreate(custom.requests[0])?.offerCodeID == "ioc1")

        let date = Date(timeIntervalSince1970: 1_900_000_000)
        let batch = builder.oneTimeCodesChange(NewOneTimeCodes(numberOfCodes: 5, expirationDate: expiry), for: Self.existing, purchase: Self.lifetime, at: date)
        let create = try #require(InAppPurchaseOneTimeCodesCreate(batch.requests[0]))
        #expect(create.offerCodeID == "ioc1")
        #expect(create.queuedAt == date)
        #expect(create.batch.numberOfCodes == 5)
    }

    @Test func aDeactivationPatchesActiveAfterCheckingIt() throws {
        let change = builder.deactivation(of: .oneTimeCodes(Self.existing.oneTimeCodes[0]), in: Self.existing, purchase: Self.lifetime)
        #expect(change.requests.map(\.path) == ["/v1/inAppPurchaseOfferCodeOneTimeUseCodes/ot1"])
        #expect(change.requests.first?.method == .patch)
        let check = try #require(change.conflictCheck)
        #expect(check.path == "/v1/inAppPurchaseOfferCodeOneTimeUseCodes/ot1")
        #expect(check.keyPath == ["data", "attributes", "active"])
        #expect(check.expected == "1")
        #expect(change.newValue == "Deactivated")

        let offer = builder.deactivation(of: .offerCode, in: Self.existing, purchase: Self.lifetime)
        #expect(offer.requests.map(\.path) == ["/v1/inAppPurchaseOfferCodes/ioc1"])
        #expect(offer.id.hasSuffix(".ioc1.deactivate"))
    }
}
