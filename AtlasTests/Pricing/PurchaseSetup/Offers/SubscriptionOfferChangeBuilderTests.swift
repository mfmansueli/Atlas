//
//  SubscriptionOfferChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Promotional offers, win-back offers and offer codes in Review & Push:
/// each its own change in the subscription's group, carrying the requests
/// the push sends, what Restore Previous Values sends back and the value
/// checked first.
@MainActor
@Suite("Subscription offer changes")
struct SubscriptionOfferChangeBuilderTests {
    static let app = NewSubscriptionChangeBuilderTests.app
    static let monthly = IntroductoryOfferChangeBuilderTests.monthly
    static let paid = OfferTerms(
        mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3, price: Decimal(string: "4.99"),
        territories: .chosen(["USA", "BRA"]), territoryPrices: ["BRA": Decimal(string: "9.90") ?? 0]
    )
    static let start = NewIntroductoryOffer.day(from: "2026-12-01") ?? .now

    private func data(_ request: PushRequest) throws -> [String: Any] {
        try #require(PushPagedRead.body(of: request)?["data"] as? [String: Any])
    }

    private func attributes(_ request: PushRequest) throws -> [String: Any] {
        try #require(data(request)["attributes"] as? [String: Any])
    }

    // MARK: - Promotional offers

    @Test func aPromotionalOfferIsCreatedWithItsTermsAndPricePlan() throws {
        let offer = NewPromotionalOffer(name: " Come back ", identifier: "come_back", terms: Self.paid)
        let change = PromotionalOfferChangeBuilder(app: Self.app).change(
            for: offer, subscription: Self.monthly, source: .assistant(client: "Claude Code"), evidence: ["Paywall.swift:12"]
        )
        #expect(change.id == PromotionalOfferChangeBuilder.changeID(appID: "app1", productID: Self.monthly.productID, identifier: "come_back"))
        #expect(PromotionalOfferChangeBuilder.owns(change))
        #expect(PurchaseSetupQueue.isSetup(change))
        #expect(SubscriptionOfferChanges.kind(of: change) == .promotional)
        #expect(change.groupID == "sub1")
        #expect(change.section == .subscriptionPricing)
        #expect(change.creation?.fields.contains { $0.id == "evidence" } == true)

        let request = try #require(change.requests.first)
        #expect(request.method == .post)
        #expect(request.path == "/v1/subscriptionPromotionalOffers")
        let attributes = try attributes(request)
        #expect(attributes["name"] as? String == "Come back")
        #expect(attributes["offerCode"] as? String == "come_back")
        #expect(attributes["offerMode"] as? String == "PAY_AS_YOU_GO")
        #expect(attributes["duration"] as? String == "ONE_MONTH")
        #expect(attributes["numberOfPeriods"] as? Int == 3)
        #expect(PushPagedRead.relationshipID("subscription", of: try data(request)) == "sub1")

        let write = try #require(SubscriptionOfferWrite(request))
        #expect(write.resource == .promotional)
        #expect(write.plan.usPrice == Decimal(string: "4.99"))
        #expect(write.plan.territoryIDs == ["USA", "BRA"])
        #expect(write.plan.territoryPrices == ["BRA": Decimal(string: "9.90")])
        #expect(write.identity == "come_back")
        // Read back as the sheet and the tools see it.
        #expect(PromotionalOfferChangeBuilder.offer(in: change)?.trimmedIdentifier == "come_back")
        #expect(PromotionalOfferChangeBuilder.offer(in: change)?.terms.territoryPrices == Self.paid.territoryPrices)
    }

    @Test func theRequestAppleGetsHasOneInlinePricePerTerritory() throws {
        let request = SubscriptionOfferWrite.create(
            .promotional, attributes: ["offerCode": "x"], plan: OfferPricesPlan(subscriptionID: "sub1", terms: Self.paid)
        )
        let write = try #require(SubscriptionOfferWrite(request))
        let sent = write.request(prices: [
            OfferPriceReader.Price(territoryID: "USA", pricePointID: "pUSA"), OfferPriceReader.Price(territoryID: "BRA", pricePointID: "pBRA"),
        ])
        let body = try #require(PushPagedRead.body(of: sent))
        #expect(body[OfferPricesPlan.metaKey] == nil)
        let prices = (((body["data"] as? [String: Any])?["relationships"] as? [String: Any])?["prices"] as? [String: Any])?["data"] as? [[String: Any]]
        #expect(prices?.compactMap { $0["id"] as? String } == ["${price1}", "${price2}"])
        #expect(prices?.first?["type"] as? String == "subscriptionPromotionalOfferPrices")
        let included = try #require(body["included"] as? [[String: Any]])
        #expect(included.count == 2)
        #expect(PushPagedRead.relationshipID("territory", of: included[1]) == "BRA")
        #expect(PushPagedRead.relationshipID("subscriptionPricePoint", of: included[1]) == "pBRA")

        // A free offer's prices name only the territory.
        let free = write.request(prices: [OfferPriceReader.Price(territoryID: "USA", pricePointID: nil)])
        let freeIncluded = try #require(PushPagedRead.body(of: free)?["included"] as? [[String: Any]])
        #expect(PushPagedRead.relationshipID("subscriptionPricePoint", of: freeIncluded[0]) == nil)
    }

    @Test func newPricesReplaceTheOffersAndRestoreTheOldOnes() throws {
        let existing = ExistingPromotionalOffer(
            id: "po1", name: "Come back", identifier: "come_back", mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3,
            prices: ExistingOfferPrices(territoryIDs: ["BRA", "USA"], usPrice: Decimal(string: "2.99"))
        )
        var terms = existing.terms
        terms.price = Decimal(string: "1.99")
        let change = PromotionalOfferChangeBuilder(app: Self.app).pricesChange(for: existing, terms: terms, subscription: Self.monthly)
        let request = try #require(change.requests.first)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/subscriptionPromotionalOffers/po1")
        #expect(SubscriptionOfferWrite(request)?.plan.usPrice == Decimal(string: "1.99"))
        #expect(SubscriptionOfferWrite(try #require(change.restoreRequests.first))?.plan.usPrice == Decimal(string: "2.99"))
        #expect(change.conflictCheck?.expected == "2.99")
        #expect(change.conflictCheck?.path.hasPrefix("/v1/subscriptionPromotionalOffers/po1/prices") == true)
    }

    @Test func deletingAnOfferSendsADelete() {
        let existing = ExistingPromotionalOffer(id: "po1", name: "Come back", identifier: "come_back", mode: .freeTrial, duration: .oneWeek)
        let change = PromotionalOfferChangeBuilder(app: Self.app).deletion(of: existing, subscription: Self.monthly)
        #expect(change.requests == [PushRequest(method: .delete, path: "/v1/subscriptionPromotionalOffers/po1", body: nil)])
        #expect(PromotionalOfferChangeBuilder.isDeletion(change))
        #expect(PurchaseSetupQueue.isSetup(change))
    }

    // MARK: - Win-back offers

    @Test func aWinBackOfferIsCreatedWithItsEligibilityAndDates() throws {
        let settings = WinBackOfferSettings(
            eligibility: WinBackEligibility(paidMonths: 2, sinceLastSubscribed: 1...6, waitMonths: nil),
            startDate: Self.start, priority: .high, promotionIntent: .autoGeneratedAssets
        )
        let offer = NewWinBackOffer(
            referenceName: "We miss you", offerID: "we_miss_you", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth), settings: settings
        )
        let change = WinBackOfferChangeBuilder(app: Self.app).change(for: offer, subscription: Self.monthly)
        #expect(WinBackOfferChangeBuilder.owns(change))
        #expect(SubscriptionOfferChanges.kind(of: change) == .winBack)
        let request = try #require(change.requests.first)
        #expect(request.path == "/v1/winBackOffers")
        let attributes = try attributes(request)
        #expect(attributes["referenceName"] as? String == "We miss you")
        #expect(attributes["offerId"] as? String == "we_miss_you")
        #expect(attributes["periodCount"] as? Int == 1)
        #expect(attributes["customerEligibilityPaidSubscriptionDurationInMonths"] as? Int == 2)
        let since = attributes["customerEligibilityTimeSinceLastSubscribedInMonths"] as? [String: Any]
        #expect(since?["minimum"] as? Int == 1)
        #expect(since?["maximum"] as? Int == 6)
        #expect(attributes["startDate"] as? String == "2026-12-01")
        #expect(attributes["priority"] as? String == "HIGH")
        #expect(attributes["promotionIntent"] as? String == "USE_AUTO_GENERATED_ASSETS")
        #expect(SubscriptionOfferWrite(request)?.plan.usPrice == nil)
        #expect(WinBackOfferChangeBuilder.offer(in: change)?.settings == settings)
    }

    @Test func newSettingsSendOnlyWhatChanged() throws {
        let old = WinBackOfferSettings(startDate: Self.start, endDate: nil, priority: .normal)
        let existing = ExistingWinBackOffer(
            id: "wb1", referenceName: "We miss you", offerID: "we_miss_you", mode: .freeTrial, duration: .oneMonth, settings: old
        )
        var new = old
        new.priority = .high
        new.endDate = NewIntroductoryOffer.day(from: "2027-01-31")
        let today = NewIntroductoryOffer.day(from: "2026-11-23") ?? .now
        let change = WinBackOfferChangeBuilder(app: Self.app).settingsChange(for: existing, settings: new, subscription: Self.monthly, today: today)
        let request = try #require(change.requests.first)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/winBackOffers/wb1")
        let sent = try attributes(request)
        #expect(Set(sent.keys) == ["priority", "endDate"])
        #expect(sent["endDate"] as? String == "2027-01-31")
        let restored = try attributes(try #require(change.restoreRequests.first))
        #expect(restored["priority"] as? String == "NORMAL")
        #expect(restored["endDate"] is NSNull)
        #expect(change.conflictCheck?.expected == "NORMAL")
        #expect(change.blockedReason == nil)
        #expect(WinBackOfferChangeBuilder.settings(in: change, over: old) == new)

        // The same settings are nothing to push.
        let same = WinBackOfferChangeBuilder(app: Self.app).settingsChange(for: existing, settings: old, subscription: Self.monthly, today: today)
        #expect(same.blockedReason == SubscriptionOfferProblem.nothingChanged.message)
    }

    @Test func aStartedOffersStartIsntSent() {
        let old = WinBackOfferSettings(startDate: Self.start)
        var new = old
        new.startDate = NewIntroductoryOffer.day(from: "2026-12-05") ?? .now
        #expect(WinBackOfferChangeBuilder.changedKeys(from: old, to: new, startIsFixed: true).isEmpty)
        #expect(WinBackOfferChangeBuilder.changedKeys(from: old, to: new, startIsFixed: false) == ["startDate"])
    }

    // MARK: - Offer codes

    @Test func anOfferCodeComesWithItsCodesMadeAfterIt() throws {
        var code = NewOfferCode(name: "Podcast listeners", terms: OfferTerms(mode: .freeTrial, duration: .threeMonths))
        code.eligibilities = [.expired, .new]
        code.offerEligibility = .replaceIntroOffers
        code.autoRenews = false
        code.customCode = NewCustomCode(code: "podcast30", numberOfCodes: 1000, expirationDate: NewIntroductoryOffer.day(from: "2026-12-31"))
        code.oneTimeCodes = NewOneTimeCodes(numberOfCodes: 500, expirationDate: NewIntroductoryOffer.day(from: "2027-01-31") ?? .now, environment: .sandbox)
        let change = OfferCodeChangeBuilder(app: Self.app).change(for: code, subscription: Self.monthly)
        #expect(OfferCodeChangeBuilder.owns(change))
        #expect(change.requests.map(\.path) == [
            "/v1/subscriptionOfferCodes", "/v1/subscriptionOfferCodeCustomCodes", "/v1/subscriptionOfferCodeOneTimeUseCodes",
        ])
        let attributes = try attributes(change.requests[0])
        #expect(attributes["name"] as? String == "Podcast listeners")
        #expect(attributes["customerEligibilities"] as? [String] == ["NEW", "EXPIRED"])
        #expect(attributes["offerEligibility"] as? String == "REPLACE_INTRO_OFFERS")
        #expect(attributes["autoRenewEnabled"] as? Bool == false)

        let custom = try data(change.requests[1])
        #expect((custom["attributes"] as? [String: Any])?["customCode"] as? String == "PODCAST30")
        #expect((custom["attributes"] as? [String: Any])?["expirationDate"] as? String == "2026-12-31")
        #expect(PushPagedRead.relationshipID("offerCode", of: custom) == "{createdID:subscriptionOfferCodes}")
        let batch = try data(change.requests[2])
        #expect((batch["attributes"] as? [String: Any])?["numberOfCodes"] as? Int == 500)
        #expect((batch["attributes"] as? [String: Any])?["environment"] as? String == "SANDBOX")
        #expect(PushPagedRead.relationshipID("offerCode", of: batch) == "{createdID:subscriptionOfferCodes}")

        let read = try #require(OfferCodeChangeBuilder.offerCode(in: change))
        #expect(read.customCode?.code == "PODCAST30")
        #expect(read.oneTimeCodes?.numberOfCodes == 500)
        #expect(OfferCodeChangeBuilder.customCodes(in: change).map(\.code) == ["PODCAST30"])
    }

    @Test func codesForAnOfferCodeItHasNameIt() throws {
        let code = ExistingOfferCode(id: "oc1", name: "Podcast", eligibilities: [.new], mode: .freeTrial, duration: .oneMonth)
        let builder = OfferCodeChangeBuilder(app: Self.app)
        let custom = builder.customCodeChange(NewCustomCode(code: "LUMEN", numberOfCodes: 10), for: code, subscription: Self.monthly)
        #expect(PushPagedRead.relationshipID("offerCode", of: try data(try #require(custom.requests.first))) == "oc1")
        let batch = builder.oneTimeCodesChange(
            NewOneTimeCodes(numberOfCodes: 5, expirationDate: Self.start), for: code, subscription: Self.monthly
        )
        #expect(batch.requests.first?.path == "/v1/subscriptionOfferCodeOneTimeUseCodes")
        #expect(custom.id != batch.id)
        #expect(PurchaseSetupQueue.isSetup(custom))
    }

    @Test func deactivatingTurnsActiveOffAfterCheckingItsOn() throws {
        let custom = ExistingCustomCode(id: "cc1", code: "LUMEN", numberOfCodes: 10)
        let code = ExistingOfferCode(
            id: "oc1", name: "Podcast", eligibilities: [.new], mode: .freeTrial, duration: .oneMonth, customCodes: [custom]
        )
        let builder = OfferCodeChangeBuilder(app: Self.app)
        let whole = builder.deactivation(of: .offerCode, in: code, subscription: Self.monthly)
        let request = try #require(whole.requests.first)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/subscriptionOfferCodes/oc1")
        #expect(try attributes(request)["active"] as? Bool == false)
        #expect(whole.conflictCheck?.expected == "1")

        let one = builder.deactivation(of: .customCode(custom), in: code, subscription: Self.monthly)
        #expect(one.requests.first?.path == "/v1/subscriptionOfferCodeCustomCodes/cc1")
        #expect(try data(try #require(one.requests.first))["type"] as? String == "subscriptionOfferCodeCustomCodes")
        #expect(one.id != whole.id)
    }

    // MARK: - Queue

    @Test func theQueueRefusesTakenIdentifiersAcrossReviewAndPush() {
        let queue = ChangeQueue()
        let offers = SubscriptionOfferQueue(app: Self.app, queue: queue)
        let extras = PurchaseExtras(offersRead: true)
        let first = NewPromotionalOffer(name: "Come back", identifier: "come_back", terms: OfferTerms(mode: .freeTrial, duration: .oneWeek))
        offers.queue(first, for: Self.monthly, extras: extras, source: .you)
        #expect(offers.queued(for: Self.monthly).count == 1)
        // Its own change doesn't count against it; another with the same
        // identifier from a different name would replace it, so a second
        // identifier is free.
        #expect(offers.problems(for: first, subscription: Self.monthly, extras: extras).isEmpty)

        var code = NewOfferCode(name: "Podcast", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth))
        code.customCode = NewCustomCode(code: "LUMEN", numberOfCodes: 10)
        offers.queue(code, for: Self.monthly, extras: extras, source: .you)
        var other = NewOfferCode(name: "Newsletter", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth))
        other.customCode = NewCustomCode(code: "lumen", numberOfCodes: 10)
        #expect(offers.problems(for: other, subscription: Self.monthly, extras: extras).contains(.customCodeTaken("LUMEN")))

        #expect(offers.othersChange(id: first.changeID(in: Self.app, subscription: Self.monthly), source: .assistant(client: "Claude Code")) != nil)
        #expect(offers.othersChange(id: first.changeID(in: Self.app, subscription: Self.monthly), source: .you) == nil)
    }
}

private extension NewPromotionalOffer {
    func changeID(in app: StoreApp, subscription: PricingProduct) -> PendingChange.ID {
        PromotionalOfferChangeBuilder.changeID(appID: app.id, productID: subscription.productID, identifier: trimmedIdentifier)
    }
}
