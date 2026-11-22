//
//  NewInAppPurchaseChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A new in-app purchase as one Review & Push change: its checks, its
/// requests in order (create, texts, availability, price, review
/// screenshot), and how it shares product IDs with new subscriptions.
@MainActor
@Suite("NewInAppPurchaseChangeBuilder")
struct NewInAppPurchaseChangeBuilderTests {
    static let app = NewSubscriptionChangeBuilderTests.app

    static func lifetime() -> NewInAppPurchase {
        NewInAppPurchase(
            referenceName: "Bruma Lifetime",
            productID: "com.lima.bruma.lifetime",
            locale: .englishUS,
            displayName: "Bruma Lifetime",
            description: "Every feature, once",
            price: Decimal(string: "149.99")
        )
    }

    private func data(_ request: PushRequest?) throws -> [String: Any] {
        let body = try #require(request.flatMap(PushPagedRead.body(of:)))
        return try #require(body["data"] as? [String: Any])
    }

    // MARK: - Checks

    @Test func aCompletePurchaseHasNoProblems() {
        #expect(Self.lifetime().problems(takenProductIDs: []).isEmpty)
        #expect(Self.lifetime().guidelineReasons.isEmpty)
    }

    @Test func everyMissingFieldIsNamed() {
        let empty = NewInAppPurchase(referenceName: "", productID: "", locale: .englishUS, displayName: "", description: "")
        #expect(empty.problems(takenProductIDs: []) == [
            .missing(.referenceName), .missing(.productID), .missing(.purchaseName), .missing(.purchaseDescription), .missing(.price),
        ])
    }

    @Test func textsKeepAppStoreConnectsLimits() {
        var purchase = Self.lifetime()
        purchase.displayName = String(repeating: "a", count: 31)
        purchase.description = String(repeating: "b", count: 46)
        let problems = purchase.problems(takenProductIDs: [])
        #expect(problems.count == 2)
        #expect(problems.allSatisfy { [.purchaseName, .purchaseDescription].contains($0.field) })
        #expect(NewSubscriptionField.purchaseName.limit == 30)
        #expect(NewSubscriptionField.purchaseDescription.limit == 45)
    }

    @Test func aTakenProductIDIsRefused() {
        let problems = Self.lifetime().problems(takenProductIDs: ["com.lima.bruma.lifetime"])
        #expect(problems.map(\.field) == [.productID])
    }

    @Test func storeTextsFollowAppReviewsRules() {
        var purchase = Self.lifetime()
        purchase.description = "Free forever, 50% off today"
        #expect(purchase.guidelineReasons.first?.hasPrefix("description:") == true)
    }

    @Test func familySharingIsSentForNonConsumablesOnly() {
        var purchase = Self.lifetime()
        purchase.isFamilySharable = true
        #expect(purchase.sentFamilySharable)
        purchase.kind = .consumable
        #expect(!purchase.sentFamilySharable)
        #expect(!NewInAppPurchaseKind.nonRenewingSubscription.supportsFamilySharing)
    }

    // MARK: - Requests

    @Test func thePushCreatesItThenItsTextsAvailabilityAndPrice() throws {
        var purchase = Self.lifetime()
        purchase.reviewNote = "Settings → Atlas Pro"
        let change = NewInAppPurchaseChangeBuilder(app: Self.app).change(for: purchase, source: .assistant(client: "Claude Code"))
        #expect(change.id == "inAppPurchaseSetup.app1.com.lima.bruma.lifetime")
        #expect(NewInAppPurchaseChangeBuilder.owns(change))
        #expect(!NewSubscriptionChangeBuilder.owns(change))
        #expect(PurchaseSetupQueue.isSetup(change))
        #expect(NewInAppPurchaseChangeBuilder.productID(of: change) == "com.lima.bruma.lifetime")
        #expect(change.requests.map(\.path) == [
            "/v2/inAppPurchases", "/v2/inAppPurchaseLocalizations", "/v1/inAppPurchaseAvailabilities", "/v1/inAppPurchasePriceSchedules",
        ])

        let create = try data(change.requests[0])
        #expect(create["type"] as? String == "inAppPurchases")
        let attributes = try #require(create["attributes"] as? [String: Any])
        #expect(attributes["name"] as? String == "Bruma Lifetime")
        #expect(attributes["productId"] as? String == "com.lima.bruma.lifetime")
        #expect(attributes["inAppPurchaseType"] as? String == "NON_CONSUMABLE")
        #expect(attributes["familySharable"] as? Bool == false)
        #expect(attributes["reviewNote"] as? String == "Settings → Atlas Pro")
        #expect(PushPagedRead.relationshipID("app", of: create) == "app1")

        let texts = try data(change.requests[1])
        #expect(texts["type"] as? String == "inAppPurchaseLocalizations")
        #expect((texts["attributes"] as? [String: Any])?["locale"] as? String == "en-US")
        #expect((texts["attributes"] as? [String: Any])?["name"] as? String == "Bruma Lifetime")
        #expect(PushPagedRead.relationshipID("version", of: texts) == "{inAppDraft:inAppPurchases/{createdID:inAppPurchases}}")

        let availability = try #require(InAppPurchaseAvailabilityEverywhere(change.requests[2]))
        #expect(availability.purchaseID == "{createdID:inAppPurchases}")

        let price = try #require(InAppPurchaseStartingPrice(change.requests[3]))
        #expect(price.purchaseID == "{createdID:inAppPurchases}")
        #expect(price.territoryID == "USA")
        #expect(price.customerPrice == Decimal(string: "149.99"))
    }

    @Test func thePriceScheduleHasTheBaseTerritorysOneManualPrice() throws {
        let step = InAppPurchaseStartingPrice(purchaseID: "iap9", territoryID: "USA", customerPrice: Decimal(string: "149.99") ?? 0)
        let body = try #require(PushPagedRead.body(of: step.schedule(pricePointID: "pp-149")))
        let data = try #require(body["data"] as? [String: Any])
        #expect(data["type"] as? String == "inAppPurchasePriceSchedules")
        #expect(PushPagedRead.relationshipID("inAppPurchase", of: data) == "iap9")
        #expect(PushPagedRead.relationshipID("baseTerritory", of: data) == "USA")
        let manual = ((data["relationships"] as? [String: Any])?["manualPrices"] as? [String: Any])?["data"] as? [[String: Any]]
        #expect(manual?.compactMap { $0["id"] as? String } == ["${base-price}"])
        let included = try #require((body["included"] as? [[String: Any]])?.first)
        #expect(included["type"] as? String == "inAppPurchasePrices")
        #expect(included["id"] as? String == "${base-price}")
        #expect(PushPagedRead.relationshipID("inAppPurchaseV2", of: included) == "iap9")
        #expect(PushPagedRead.relationshipID("inAppPurchasePricePoint", of: included) == "pp-149")
        #expect(step.pricePointsPath.hasPrefix("/v2/inAppPurchases/iap9/pricePoints?filter%5Bterritory%5D=USA"))
    }

    @Test func availabilityIsEveryTerritoryAndNewOnes() throws {
        let request = InAppPurchaseAvailabilityEverywhere(purchaseID: "iap9", availableInNewTerritories: true).request(territoryIDs: ["USA", "BRA"])
        let data = try data(request)
        #expect(request.path == "/v1/inAppPurchaseAvailabilities")
        #expect(data["type"] as? String == "inAppPurchaseAvailabilities")
        #expect((data["attributes"] as? [String: Any])?["availableInNewTerritories"] as? Bool == true)
        #expect(PushPagedRead.relationshipID("inAppPurchase", of: data) == "iap9")
        let territories = ((data["relationships"] as? [String: Any])?["availableTerritories"] as? [String: Any])?["data"] as? [[String: Any]]
        #expect(territories?.compactMap { $0["id"] as? String } == ["USA", "BRA"])
    }

    @Test func aReviewScreenshotIsTheLastStep() throws {
        var purchase = Self.lifetime()
        purchase.reviewScreenshot = PurchaseReviewScreenshotFile(
            id: "f1", fileName: "paywall.png", checksum: "abc", pixelSize: PixelSize(width: 1290, height: 2796), byteCount: 1234
        )
        let builder = NewInAppPurchaseChangeBuilder(app: Self.app, folder: .temporary)
        let change = builder.change(for: purchase)
        let step = try #require(change.requests.last.flatMap(PurchaseReviewScreenshotPush.init))
        #expect(step.owner == .inAppPurchase)
        #expect(step.ownerID == "{createdID:inAppPurchases}")
        #expect(step.fileName == "paywall.png")
        #expect(step.fileSize == 1234)
        #expect(step.checksum == "abc")
        #expect(step.path.hasSuffix("/app1/f1.png"))
        #expect(change.creation?.fields.contains { $0.id == PurchaseReviewScreenshotChangeBuilder.fieldID } == true)
    }

    // MARK: - Product IDs

    @Test func newSubscriptionsAndPurchasesShareProductIDs() {
        let queue = ChangeQueue()
        let purchase = NewInAppPurchaseChangeBuilder(app: Self.app).change(for: Self.lifetime())
        let subscription = NewSubscriptionChangeBuilder(app: Self.app).change(for: NewSubscriptionChangeBuilderTests.monthly())
        queue.upsert(contentsOf: [purchase, subscription])

        let taken = NewSubscriptionChangeBuilder.takenProductIDs(appID: "app1", catalog: nil, queue: queue, except: purchase.id)
        #expect(taken == ["com.lima.bruma.premium.monthly"])
        let all = NewSubscriptionChangeBuilder.takenProductIDs(appID: "app1", catalog: nil, queue: queue, except: subscription.id)
        #expect(all == ["com.lima.bruma.lifetime"])
        #expect(NewSubscriptionChangeBuilder.queued(in: queue, appID: "app1").map(\.id) == [subscription.id])
        #expect(NewInAppPurchaseChangeBuilder.queued(in: queue, appID: "app1").map(\.id) == [purchase.id])
    }
}
