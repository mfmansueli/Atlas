//
//  WinBackPlanTypeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A win-back offer's payment plan (`targetSubscriptionPlanType`): sent
/// when it's created, left out for every plan, read back from App Store
/// Connect, and never part of an edit (App Store Connect's update doesn't
/// take it).
@MainActor
@Suite("Win-back offer · payment plan")
struct WinBackPlanTypeTests {
    private static let app = NewSubscriptionChangeBuilderTests.app
    private static let monthly = IntroductoryOfferChangeBuilderTests.monthly
    private static let start = NewIntroductoryOffer.day(from: "2099-01-01") ?? .now

    private func offer(_ plan: SubscriptionPlanType?) -> NewWinBackOffer {
        NewWinBackOffer(
            referenceName: "We miss you", offerID: "we_miss_you", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth),
            settings: WinBackOfferSettings(startDate: Self.start), targetPlanType: plan
        )
    }

    private func attributes(_ change: PendingChange) throws -> [String: Any] {
        let request = try #require(change.requests.first)
        return try #require((PushPagedRead.body(of: request)?["data"] as? [String: Any])?["attributes"] as? [String: Any])
    }

    @Test func aPlanIsSentWhenTheOfferIsCreated() throws {
        let change = WinBackOfferChangeBuilder(app: Self.app).change(for: offer(.monthly), subscription: Self.monthly)
        #expect(try attributes(change)["targetSubscriptionPlanType"] as? String == "MONTHLY")
        #expect(WinBackOfferChangeBuilder.offer(in: change)?.targetPlanType == .monthly)
        #expect(change.creation?.fields.first { $0.id == "plan" }?.newValue == SubscriptionPlanType.monthly.title)
    }

    @Test func everyPlanSendsNone() throws {
        let change = WinBackOfferChangeBuilder(app: Self.app).change(for: offer(nil), subscription: Self.monthly)
        #expect(try attributes(change)["targetSubscriptionPlanType"] == nil)
        #expect(WinBackOfferChangeBuilder.offer(in: change)?.targetPlanType == nil)
        #expect(change.creation?.fields.contains { $0.id == "plan" } == false)
        #expect(SubscriptionPlanType.title(of: nil) == String(localized: "Every plan"))
    }

    @Test func theOfferAppStoreConnectHasSaysItsPlan() throws {
        let resource: [String: Any] = [
            "id": "wb1",
            "attributes": [
                "referenceName": "We miss you", "offerId": "we_miss_you", "duration": "ONE_MONTH", "offerMode": "FREE_TRIAL",
                "startDate": "2099-01-01", "targetSubscriptionPlanType": "UPFRONT",
            ],
        ]
        let existing = try #require(ExistingWinBackOffer(resource: resource))
        #expect(existing.targetPlanType == .upfront)
        #expect(existing.subscriptionOffer(subscriptionPrice: nil).eligibility.contains(SubscriptionPlanType.upfront.title))
        #expect(ExistingWinBackOffer.listPath(subscriptionID: "sub1").contains("targetSubscriptionPlanType"))

        var unknown = resource
        unknown["attributes"] = ["duration": "ONE_MONTH", "offerMode": "FREE_TRIAL", "startDate": "2099-01-01", "targetSubscriptionPlanType": "WEEKLY"]
        #expect(ExistingWinBackOffer(resource: unknown)?.targetPlanType == nil)
    }

    @Test func anEditNeverSendsThePlan() throws {
        let existing = ExistingWinBackOffer(
            id: "wb1", referenceName: "We miss you", offerID: "we_miss_you", mode: .freeTrial, duration: .oneMonth,
            settings: WinBackOfferSettings(startDate: Self.start), targetPlanType: .monthly
        )
        var settings = existing.settings
        settings.priority = .high
        let change = WinBackOfferChangeBuilder(app: Self.app).settingsChange(for: existing, settings: settings, subscription: Self.monthly)
        #expect(try Set(attributes(change).keys) == ["priority"])
    }
}
