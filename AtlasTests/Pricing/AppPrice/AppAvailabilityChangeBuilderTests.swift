//
//  AppAvailabilityChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Where the app is sold as Review & Push changes: the first availability
/// in one `POST /v2/appAvailabilities`, then a `PATCH` per country or region.
@MainActor
@Suite("App availability changes")
struct AppAvailabilityChangeBuilderTests {
    private let builder = AppAvailabilityChangeBuilder(app: AppPriceChangeBuilderTests.app)

    /// The change's first request, or a failed test.
    private static func first(_ requests: [PushRequest]) throws -> PushRequest {
        try #require(requests.first)
    }

    private static func object(_ request: PushRequest) throws -> [String: Any] {
        let body = try #require(request.body)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func theFirstAvailabilityListsEveryTerritory() throws {
        var setup = AppAvailabilitySetup.everywhere(["USA", "BRA", "CHN"])
        setup.availableTerritoryIDs.remove("CHN")
        setup.availableInNewTerritories = false
        let change = builder.setupChange(setup)

        #expect(change.id == "appAvailability.app1.setup")
        #expect(change.creation?.title == "Set up availability")
        #expect(change.newValue == "2 of 3 countries or regions: Brazil and United States")
        #expect(change.restoreRequests.isEmpty)
        let request = try Self.first(change.requests)
        #expect(request.method == .post)
        #expect(request.path == "/v2/appAvailabilities")

        let object = try Self.object(request)
        let data = try #require(object["data"] as? [String: Any])
        #expect((data["attributes"] as? [String: Any])?["availableInNewTerritories"] as? Bool == false)
        let relationships = try #require(data["relationships"] as? [String: Any])
        #expect(((relationships["app"] as? [String: Any])?["data"] as? [String: Any])?["id"] as? String == "app1")
        let linked = try #require((relationships["territoryAvailabilities"] as? [String: Any])?["data"] as? [[String: Any]])
        #expect(linked.map { $0["id"] as? String } == ["${USA}", "${BRA}", "${CHN}"])
        let included = try #require(object["included"] as? [[String: Any]])
        #expect(included.map { $0["id"] as? String } == ["${USA}", "${BRA}", "${CHN}"])
        #expect(included.map { ($0["attributes"] as? [String: Any])?["available"] as? Bool } == [true, true, false])
        let territory = ((included[2]["relationships"] as? [String: Any])?["territory"] as? [String: Any])?["data"] as? [String: Any]
        #expect(territory?["id"] as? String == "CHN")
    }

    @Test func aPreOrderGoesOnTheTerritoriesItsSoldIn() throws {
        var setup = AppAvailabilitySetup.everywhere(["USA", "CHN"])
        setup.availableTerritoryIDs = ["USA"]
        setup.preOrderReleaseDate = "2026-12-20"
        let change = builder.setupChange(setup)

        let included = try #require(Self.object(Self.first(change.requests))["included"] as? [[String: Any]])
        let usa = included[0]["attributes"] as? [String: Any]
        let china = included[1]["attributes"] as? [String: Any]
        #expect(usa?["releaseDate"] as? String == "2026-12-20")
        #expect(usa?["preOrderEnabled"] as? Bool == true)
        #expect(china?["releaseDate"] == nil)
        #expect(change.creation?.fields.first { $0.id == "preOrder" }?.newValue == "On · released 2026-12-20")
    }

    @Test func aQueuedSetupReadsBack() throws {
        var setup = AppAvailabilitySetup.everywhere(["USA", "BRA"])
        setup.availableTerritoryIDs = ["BRA"]
        setup.preOrderReleaseDate = "2026-12-20"
        setup.availableInNewTerritories = false
        let change = builder.setupChange(setup)
        let read = try #require(AppPriceAvailabilityRequests.availabilitySetup(in: Self.first(change.requests)))
        #expect(read == setup)
    }

    @Test func everywhereReadsAsEveryCountry() {
        let change = builder.setupChange(.everywhere(["USA", "BRA"]))
        #expect(change.newValue == "Every country or region (2)")
        #expect(change.creation?.fields.first { $0.id == "newTerritories" }?.newValue == "Available automatically")
    }

    @Test func aProblemBlocksTheSetup() {
        let setup = AppAvailabilitySetup(allTerritoryIDs: ["USA"], availableTerritoryIDs: [])
        let change = builder.setupChange(setup, problems: [.noTerritory])
        #expect(change.blockedReason == AppAvailabilityProblem.noTerritory.message)
    }

    @Test func oneTerritoryIsAPatchThatCanBeUndone() throws {
        let brazil = AppTerritoryAvailability(id: "ta-bra", territoryID: "BRA", isAvailable: true)
        let change = try #require(builder.territoryChange(brazil, available: false))

        #expect(change.id == "appAvailability.app1.BRA")
        #expect(change.title == "Availability · Brazil")
        #expect(change.flagRegion == "BR")
        #expect(change.oldValue == "Available")
        #expect(change.newValue == "Not available")
        let write = try #require(AppPriceAvailabilityRequests.territoryWrite(in: Self.first(change.requests)))
        #expect(write.territoryAvailabilityID == "ta-bra")
        #expect(write.available == false)
        #expect(change.requests.first?.path == "/v1/territoryAvailabilities/ta-bra")
        let restore = try #require(AppPriceAvailabilityRequests.territoryWrite(in: Self.first(change.restoreRequests)))
        #expect(restore.available == true)
    }

    @Test func aTerritoryAlreadyThatWayIsNoChange() {
        let brazil = AppTerritoryAvailability(id: "ta-bra", territoryID: "BRA", isAvailable: true)
        #expect(builder.territoryChange(brazil, available: true) == nil)
    }

    @Test func queuedWritesIncludeAppCompliancesStopSelling() {
        let queue = ChangeQueue()
        let china = PendingChange(
            id: "appInfo.app1.appCompliance.availability.CHN",
            appID: "app1",
            section: .appInformation,
            group: "App Information · App Compliance",
            title: "Availability · China mainland",
            oldValue: "Available",
            newValue: "Not available",
            requests: [AppPriceAvailabilityRequests.territory("ta-chn", available: false)]
        )
        queue.upsert(china)
        #expect(AppAvailabilityChangeBuilder.queuedTerritoryWrites(in: queue, appID: "app1") == ["ta-chn": false])
        #expect(AppAvailabilityChangeBuilder.queuedTerritoryWrites(in: queue, appID: "other").isEmpty)
    }
}
