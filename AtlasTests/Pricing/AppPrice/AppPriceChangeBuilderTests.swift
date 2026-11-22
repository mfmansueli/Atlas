//
//  AppPriceChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The app's own price as one Review & Push change: a `POST
/// /v1/appPriceSchedules` from today, what it shows, and when it can be
/// restored.
@MainActor
@Suite("App price changes")
struct AppPriceChangeBuilderTests {
    static let app = StoreApp(id: "app1", name: "Quiet Timer", bundleID: "dev.northpier.quiet")
    private let builder = AppPriceChangeBuilder(app: Self.app)

    /// The change's first request, or a failed test.
    private static func first(_ requests: [PushRequest]) throws -> PushRequest {
        try #require(requests.first)
    }

    static let paid = PricePoint(customerPrice: Decimal(string: "2.99")!, proceeds: Decimal(string: "2.54")!, appStoreConnectID: "pp-299")
    static let free = PricePoint(customerPrice: 0, proceeds: 0, appStoreConnectID: "pp-0")

    private static func object(_ request: PushRequest) throws -> [String: Any] {
        let body = try #require(request.body)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func aFirstPriceIsOneScheduleFromToday() throws {
        let change = builder.change(point: Self.paid, in: .unitedStates, replacing: .notSet)

        #expect(change.id == "appPrice.app1")
        #expect(change.section == .subscriptionPricing)
        #expect(change.oldValue == "No price")
        #expect(change.newValue == "$2.99 in United States · equalized everywhere else")
        #expect(change.blockedReason == nil)
        #expect(change.restoreRequests.isEmpty)
        #expect(change.creation?.title == "Set up the app’s price")
        #expect(change.creation?.detail.contains("Paid Applications agreement") == true)
        let request = try Self.first(change.requests)
        #expect(change.requests.count == 1)
        #expect(request.method == .post)
        #expect(request.path == "/v1/appPriceSchedules")

        let object = try Self.object(request)
        let data = try #require(object["data"] as? [String: Any])
        #expect(data["type"] as? String == "appPriceSchedules")
        let relationships = try #require(data["relationships"] as? [String: Any])
        #expect(((relationships["app"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "app1")
        #expect(((relationships["baseTerritory"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "USA")
        let manual = try #require((relationships["manualPrices"] as? [String: Any])?["data"] as? [[String: Any]])
        #expect(manual.map { $0["id"] as? String } == ["${price1}"])
        let included = try #require(object["included"] as? [[String: Any]])
        #expect(included.count == 1)
        #expect(included[0]["type"] as? String == "appPrices")
        #expect(included[0]["id"] as? String == "${price1}")
        // No start date: it starts as soon as Apple processes it.
        #expect((included[0]["attributes"] as? [String: Any])?["startDate"] is NSNull)
        let point = ((included[0]["relationships"] as? [String: Any])?["appPricePoint"] as? [String: Any])?["data"] as? [String: Any]
        #expect(point?["type"] as? String == "appPricePoints")
        #expect(point?["id"] as? String == "pp-299")
    }

    @Test func aQueuedScheduleReadsBack() throws {
        let change = builder.change(point: Self.paid, in: AppTerritory(id: "BRA", currencyCode: "BRL"), replacing: .notSet)
        let read = try #require(AppPriceAvailabilityRequests.priceSchedule(in: Self.first(change.requests)))
        #expect(read.baseTerritoryID == "BRA")
        #expect(read.pricePointID == "pp-299")
        #expect(change.flagRegion == "BR")
    }

    @Test func freeIsFreeEverywhereWithoutProceeds() {
        let change = builder.change(point: Self.free, in: .unitedStates, replacing: .notSet)
        #expect(change.newValue == "Free everywhere")
        #expect(change.creation?.fields.map(\.id) == ["baseTerritory", "price"])
        #expect(change.creation?.fields.last?.newValue == "Free")
        #expect(change.creation?.detail.contains("Paid Applications") == false)
    }

    @Test func changingAPriceCanPutTheOldOneBack() throws {
        let current = AppCurrentPrice(scheduleID: "s1", baseTerritoryID: "USA", currencyCode: "USD", point: Self.free)
        let change = builder.change(point: Self.paid, in: .unitedStates, replacing: .set(current))

        #expect(change.oldValue == "Free")
        #expect(change.creation?.title == "Change the app’s price")
        #expect(change.creation?.fields.first { $0.id == "price" }?.oldValue == "Free")
        let restore = try #require(AppPriceAvailabilityRequests.priceSchedule(in: Self.first(change.restoreRequests)))
        #expect(restore.pricePointID == "pp-0")
        #expect(restore.baseTerritoryID == "USA")
    }

    @Test func aScheduleWithPricesSetByHandIsntRestored() {
        let current = AppCurrentPrice(
            scheduleID: "s1", baseTerritoryID: "USA", currencyCode: "USD", point: Self.paid, otherManualTerritoryIDs: ["BRA", "JPN"], laterChangeCount: 1
        )
        let change = builder.change(point: Self.free, in: .unitedStates, replacing: .set(current))
        #expect(change.restoreRequests.isEmpty)
        #expect(change.creation?.detail.contains("2 other countries or regions") == true)
    }

    @Test func aPointWithoutAnAppleIDIsBlocked() {
        let point = PricePoint(customerPrice: 1, proceeds: 0.7)
        let change = builder.change(point: point, in: .unitedStates, replacing: .notSet)
        #expect(change.requests.isEmpty)
        #expect(change.isBlocked)
    }

    @Test func theAssistantsReasonAndEvidenceShow() {
        let change = builder.change(
            point: Self.paid, in: .unitedStates, replacing: .notSet,
            source: .assistant(client: "Claude Code"), reason: "The paywall sells it once.", evidence: ["Paywall.swift:4"]
        )
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.creation?.detail.hasSuffix("The paywall sells it once.") == true)
        #expect(change.creation?.fields.last?.id == "evidence")
        #expect(change.creation?.fields.last?.newValue == "Paywall.swift:4")
    }

    @Test func appSaleChangesArentSubscriptionPriceChanges() {
        let change = builder.change(point: Self.paid, in: .unitedStates, replacing: .notSet)
        #expect(AppPriceChangeBuilder.owns(change))
        #expect(!PricingViewModel.isPriceChange(change))
    }
}
