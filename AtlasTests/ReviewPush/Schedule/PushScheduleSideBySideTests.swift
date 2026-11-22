//
//  PushScheduleSideBySideTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Many similar creates (a price per territory, a new language, a new
/// subscription) go side by side, a few at once, instead of one after the
/// other; two of the same resource still wait, and the app's other changes
/// keep their order around them.
@MainActor
@Suite("Push schedule · side by side")
struct PushScheduleSideBySideTests {
    private let builder = NewSubscriptionChangeBuilder(app: NewSubscriptionChangeBuilderTests.app)

    private func change(
        _ id: String, app: StoreApp.ID = "lumen", section: AppWorkspaceSection = .subscriptionPricing, _ request: PushRequest
    ) -> PendingChange {
        PendingChange(id: id, appID: app, section: section, group: "G", title: id, oldValue: "", newValue: "new", requests: [request])
    }

    /// One territory's new price, as `PriceChangeFactory` writes it.
    private func price(_ territory: String, subscription: String = "annual", app: StoreApp.ID = "lumen") throws -> PendingChange {
        let body = SubscriptionPriceCreateRequest(subscriptionID: subscription, territoryID: territory, pricePointID: "pp-\(territory)")
        return try change("price.\(subscription).\(territory)", app: app, PushRequest.json(.post, "/v1/subscriptionPrices", body))
    }

    private func ordered(_ id: String) -> PendingChange {
        change(id, PushRequest(method: .post, path: "/v1/subscriptionPromotionalOffers", body: Data("{}".utf8)))
    }

    /// A new In-App Texts language into the owner's draft.
    private func inAppText(_ locale: String, owner: String = "subscriptions/sub1") -> PendingChange {
        let document = StorePageWriteDocument.create(
            type: "subscriptionLocalizations",
            attributes: ["locale": locale, "name": "Premium"],
            parent: "version",
            parentType: "subscriptionVersions",
            parentID: "{inAppDraft:\(owner)}"
        )
        return change("inApp.\(owner).\(locale)", section: .storePage, PushRequest(method: .post, path: "/v2/subscriptionLocalizations", body: document.encoded()))
    }

    /// A new Store Page language at the app or the version level.
    private func storeLocale(_ locale: String, level: ListingFieldLevel) -> PendingChange {
        let type = ListingChangeBuilder.localizationType(at: level)
        let document = StorePageWriteDocument.create(
            type: type,
            attributes: ["locale": locale, "name": "Lumen"],
            parent: level == .app ? "appInfo" : "appStoreVersion",
            parentType: level == .app ? "appInfos" : "appStoreVersions",
            parentID: level == .app ? "info1" : "v1"
        )
        return change("listing.\(locale).\(type)", section: .storePage, PushRequest(method: .post, path: "/v1/\(type)", body: document.encoded()))
    }

    @Test func pricesInDifferentTerritoriesGoSideBySide() throws {
        let waits = try PushSchedule.waits(for: ["BRA", "MEX", "CHL", "ARG"].map { try price($0) })
        #expect(waits == [[], [], [], []])
    }

    @Test func twoPricesOfOneTerritoryStillGoInOrder() throws {
        let waits = try PushSchedule.waits(for: [price("BRA"), price("MEX"), price("BRA"), price("BRA", subscription: "monthly")])
        #expect(waits == [[], [], [0], []])
    }

    /// The app's ordered changes wait for the prices before them, and the
    /// prices after them wait for them; another app's don't.
    @Test func theAppsOtherChangesKeepTheirOrderAroundThem() throws {
        let waits = try PushSchedule.waits(for: [
            ordered("offer.first"),
            price("BRA"),
            price("MEX"),
            ordered("offer.second"),
            price("CHL"),
            price("PER", app: "habitat"),
        ])
        #expect(waits == [[], [0], [0], [0, 1, 2], [0, 3], []])
    }

    /// A price per territory is what a push of 175 territories is: they no
    /// longer wait for each other, so 8 go at once.
    @Test func manyPricesAreReadyAtOnce() throws {
        let territories = TerritoryCatalog.standard.territories.map(\.id)
        let waits = try PushSchedule.waits(for: territories.map { try price($0) })
        #expect(waits.joined().isEmpty)
    }

    @Test func twoNewSubscriptionsInOneGroupDontWaitForEachOther() {
        var annual = NewSubscriptionChangeBuilderTests.monthly()
        annual.productID = "com.lima.bruma.premium.annual"
        annual.referenceName = "Bruma Premium Annual"
        annual.period = .oneYear
        let monthly = builder.change(for: NewSubscriptionChangeBuilderTests.monthly())
        let yearly = builder.change(for: annual)

        #expect(PushSideBySideKey.of(monthly) != nil)
        #expect(PushSideBySideKey.of(monthly) != PushSideBySideKey.of(yearly))
        var later = ordered("offer")
        later.appID = monthly.appID
        #expect(PushSchedule.waits(for: [monthly, yearly, later]) == [[], [], [0, 1]])
    }

    @Test func newInAppTextLanguagesGoSideBySideButOneLocaleWaits() {
        let waits = PushSchedule.waits(for: [
            inAppText("de-DE"),
            inAppText("fr-FR"),
            inAppText("de-DE"),
            inAppText("de-DE", owner: "subscriptions/sub2"),
        ])
        #expect(waits == [[], [], [0], []])
    }

    /// A language's app and version pages keep their order; other languages
    /// go beside them.
    @Test func newStorePageLanguagesGoSideBySide() {
        let waits = PushSchedule.waits(for: [
            storeLocale("fr-FR", level: .app),
            storeLocale("fr-FR", level: .version),
            storeLocale("de-DE", level: .app),
            storeLocale("de-DE", level: .version),
        ])
        #expect(waits == [[], [0], [], [2]])
    }

    @Test func createsWithSomethingToFillInOrUnknownCollectionsKeepTheOrder() throws {
        let placeholder = SubscriptionPriceCreateRequest(subscriptionID: "{createdID:subscriptions}", territoryID: "BRA", pricePointID: "pp")
        let filled = try change("price.new.BRA", PushRequest.json(.post, "/v1/subscriptionPrices", placeholder))
        #expect(PushSideBySideKey.of(filled) == nil)
        #expect(PushSideBySideKey.of(ordered("offer")) == nil)
        #expect(PushSideBySideKey.of(change("bare", PushRequest(method: .post, path: "/v1/subscriptionPrices"))) == nil)
        #expect(try PushSideBySideKey.of(price("BRA")) == "subscriptionPrices:annual:BRA")
    }
}
