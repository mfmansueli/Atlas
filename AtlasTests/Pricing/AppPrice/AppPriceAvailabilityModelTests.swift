//
//  AppPriceAvailabilityModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Pricing's App Price and Availability cards: what they read, and the
/// changes Add Pricing…, Set Up Availability… and Edit Countries and
/// Regions… queue.
@MainActor
@Suite("App price and availability cards")
struct AppPriceAvailabilityModelTests {
    private let queue = ChangeQueue()
    private static let quiet = StoreApp(id: DebugFixtures.AppID.quiet, name: "Quiet Timer", bundleID: "dev.northpier.quiet")
    private static let tempo = StoreApp(id: DebugFixtures.AppID.tempo, name: "Tempo Metronome", bundleID: "com.northpier.tempo")

    /// The change's first request, or a failed test.
    private static func first(_ requests: [PushRequest]) throws -> PushRequest {
        try #require(requests.first)
    }

    private func model(_ app: StoreApp, services: DebugAppPriceAvailabilityServices = DebugAppPriceAvailabilityServices()) async -> AppPriceAvailabilityModel {
        let model = AppPriceAvailabilityModel(app: app, services: services, queue: queue)
        await model.load()
        return model
    }

    @Test func aNewAppHasNeitherPriceNorAvailability() async {
        let model = await model(Self.quiet)
        #expect(model.price.value == .notSet)
        #expect(model.availability.value == .notSet)
        #expect(model.defaultBaseTerritory == .unitedStates)
    }

    @Test func addPricingQueuesTheChosenPoint() async throws {
        let model = await model(Self.quiet)
        await model.loadLadder(for: "USA")
        let ladder = try #require(model.ladder(for: "USA").value)
        let point = try #require(ladder.points.first { $0.customerPrice == Decimal(string: "2.99") })
        model.isPriceSheetPresented = true

        model.queuePrice(point, in: .unitedStates)

        #expect(!model.isPriceSheetPresented)
        let change = try #require(model.queuedPrice)
        #expect(change.oldValue == "No price")
        #expect(try AppPriceAvailabilityRequests.priceSchedule(in: Self.first(change.requests))?.pricePointID == point.appStoreConnectID)
        model.discardQueuedPrice()
        #expect(model.queuedPrice == nil)
    }

    @Test func setUpAvailabilityQueuesItWithItsProblems() async throws {
        let model = await model(Self.quiet)
        model.today = { Date(timeIntervalSince1970: 1_795_000_000) }
        await model.loadTerritories()
        let ids = try #require(model.territories.value).map(\.id)
        var setup = AppAvailabilitySetup.everywhere(ids)
        setup.preOrderReleaseDate = AppAvailabilityRules.day(model.today())

        #expect(model.problems(for: setup).count == 1)
        model.queueSetup(setup)
        let change = try #require(model.queuedSetup)
        #expect(change.isBlocked)
        #expect(model.queuedSetupValue?.allTerritoryIDs == ids)

        setup.preOrderReleaseDate = nil
        model.queueSetup(setup)
        #expect(model.queuedSetup?.isBlocked == false)
    }

    @Test func editingCountriesQueuesOnlyWhatDiffers() async throws {
        let model = await model(Self.tempo)
        let availability = try #require(model.availability.value?.availability)
        let total = availability.territories.count
        #expect(model.shownAvailableCount == total - 1)

        model.queueTerritories(["CHN": true, "USA": false, "BRA": true])

        #expect(queue.changes.map(\.id).sorted() == [
            AppAvailabilityChangeBuilder.territoryChangeID(appID: Self.tempo.id, territoryID: "CHN"),
            AppAvailabilityChangeBuilder.territoryChangeID(appID: Self.tempo.id, territoryID: "USA"),
        ])
        #expect(model.queuedTerritoryCount == 2)
        #expect(model.shownAvailableCount == total - 1)
        let china = try #require(availability.territory("CHN"))
        #expect(model.isAvailable(china))

        // Putting the US back drops its change.
        model.queueTerritories(["USA": true])
        #expect(queue.changes.count == 1)
        #expect(model.queuedTerritoryCount == 1)
    }

    @Test func aPricedAppShowsItsPrice() async throws {
        let model = await model(Self.tempo)
        let current = try #require(model.price.value?.current)
        #expect(current.formattedPrice == "$2.99")
        #expect(current.baseTerritoryID == "USA")
    }

    @Test func aFailedReadSaysWhy() async {
        let model = await model(Self.tempo, services: DebugAppPriceAvailabilityServices(error: .server(statusCode: 500, detail: nil)))
        #expect(model.price.errorMessage?.hasPrefix("The price didn’t load. Apple didn’t answer. Try again in a minute.") == true)
        #expect(model.availability.errorMessage?.hasPrefix("Availability didn’t load. Apple didn’t answer.") == true)
        #expect(model.price.errorMessage?.contains("Details: HTTP 500") == true)
    }

    @Test func keepMyPricesLeavesTheAppsPriceQueued() async {
        let model = await model(Self.quiet)
        model.queuePrice(DebugAppPriceAvailabilityServices.ladder(territoryID: "USA").points[0], in: .unitedStates)
        let pricing = PricingViewModel(
            app: Self.quiet, services: DebugPricingServices(), queue: queue, modes: PricingModeStore(defaults: nil), commission: .smallBusiness
        )
        #expect(pricing.pendingPriceChangeCount == 0)
        pricing.confirmKeepPrices()
        #expect(model.queuedPrice != nil)
    }
}
#endif
