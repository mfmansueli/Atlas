//
//  AppPriceAvailabilityToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_app_price_and_availability`, `propose_app_price` and
/// `propose_availability`: the app's own price and where it's sold, and an
/// assistant's proposals queued in Review & Push, or refused with why.
@MainActor
@Suite("App price and availability tools")
struct AppPriceAvailabilityToolsTests {
    private let changes = ChangeQueue()
    /// Quiet Timer has neither price nor availability; Tempo is $2.99
    /// everywhere but China mainland.
    private static let quiet = StoreApp(id: DebugFixtures.AppID.quiet, name: "Quiet Timer", bundleID: "dev.northpier.quiet", primaryLocale: "en-US")
    private static let tempoID = DebugFixtures.AppID.tempo

    /// The change's first request, or a failed test.
    private static func first(_ requests: [PushRequest]) throws -> PushRequest {
        try #require(requests.first)
    }

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue], client: String = "Claude Code") async throws -> MCPToolOutcome {
        let workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + [Self.quiet], changes: changes)
        return try await tool.call(MCPToolArguments(arguments), in: MCPToolContext(workspace: workspace, clientName: client))
    }

    private func status(_ outcome: MCPToolOutcome) -> String? {
        outcome.result.objectValue?["status"]?.stringValue
    }

    @Test func theToolsAreRegistered() {
        let names = MCPToolbox.standard.toolNames
        #expect(names.contains("get_app_price_and_availability"))
        #expect(names.contains("propose_app_price"))
        #expect(names.contains("propose_availability"))
    }

    // MARK: - get_app_price_and_availability

    @Test func aNewAppReadsNotSet() async throws {
        let outcome = try await call(GetAppPriceAndAvailabilityTool(), ["appId": "Quiet Timer"])
        let result = try #require(outcome.result.objectValue)
        #expect(result["price"]?.objectValue?["state"] == "notSet")
        #expect(result["availability"]?.objectValue?["state"] == "notSet")
        #expect(result["queuedPrice"] == .null)
        #expect(result["territoryCount"]?.intValue == TerritoryCatalog.standard.territories.count)
    }

    @Test func aPricedAppReadsItsPriceAndPoints() async throws {
        let outcome = try await call(GetAppPriceAndAvailabilityTool(), ["appId": "Tempo Metronome", "territory": "US"])
        let result = try #require(outcome.result.objectValue)
        let price = try #require(result["price"]?.objectValue)
        #expect(price["state"] == "set")
        #expect(price["baseTerritory"] == "USA")
        #expect(price["price"]?.doubleValue == 2.99)
        let availability = try #require(result["availability"]?.objectValue)
        #expect(availability["notAvailable"] == ["CHN"])
        let points = try #require(result["pricePoints"]?.objectValue)
        #expect(points["territory"] == "USA")
        let listed = try #require(points["points"]?.arrayValue)
        #expect(listed.contains { $0.objectValue?["current"] == true })
        #expect(listed.first?.objectValue?["free"] == true)
    }

    @Test func anUnknownTerritoryIsAnArgumentError() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(GetAppPriceAndAvailabilityTool(), ["appId": "Tempo Metronome", "territory": "Atlantis"])
        }
    }

    // MARK: - propose_app_price

    @Test func aPriceOnApplesLadderIsQueued() async throws {
        let outcome = try await call(ProposeAppPriceTool(), [
            "appId": "Quiet Timer", "price": .double(1.99), "reason": "The paywall sells it once.", "evidence": ["Store.swift:3"],
        ])
        #expect(status(outcome) == "queued")
        let change = try #require(changes.change(id: AppPriceChangeBuilder.changeID(appID: Self.quiet.id)))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.newValue == "$1.99 in United States · equalized everywhere else")
        #expect(change.creation?.detail.contains("The paywall sells it once.") == true)
        #expect(try AppPriceAvailabilityRequests.priceSchedule(in: Self.first(change.requests))?.pricePointID == "debug-USA-1.99")
    }

    @Test func freeIsAPrice() async throws {
        let outcome = try await call(ProposeAppPriceTool(), ["appId": "Quiet Timer", "price": "free", "territory": "BR"])
        #expect(status(outcome) == "queued")
        let change = try #require(changes.change(id: AppPriceChangeBuilder.changeID(appID: Self.quiet.id)))
        #expect(change.newValue == "Free everywhere")
        #expect(change.flagRegion == "BR")
    }

    @Test func aPriceOffTheLadderIsRefusedWithTheNearest() async throws {
        let outcome = try await call(ProposeAppPriceTool(), ["appId": "Quiet Timer", "price": .double(2.5)])
        #expect(status(outcome) == "refused")
        #expect(outcome.result.objectValue?["nearest"]?.arrayValue?.isEmpty == false)
        #expect(changes.changes.isEmpty)
    }

    @Test func todaysPriceIsUnchanged() async throws {
        let outcome = try await call(ProposeAppPriceTool(), ["appId": "Tempo Metronome", "price": .double(2.99)])
        #expect(status(outcome) == "unchanged")
        #expect(changes.changes.isEmpty)
    }

    @Test func thePersonsOwnPriceIsntReplaced() async throws {
        let mine = AppPriceChangeBuilder(app: Self.quiet).change(
            point: DebugAppPriceAvailabilityServices.ladder(territoryID: "USA").points[3], in: .unitedStates, replacing: .notSet
        )
        changes.upsert(mine)
        let outcome = try await call(ProposeAppPriceTool(), ["appId": "Quiet Timer", "price": .double(1.99)])
        #expect(status(outcome) == "refused")
        #expect(changes.change(id: mine.id)?.newValue == mine.newValue)
    }

    // MARK: - propose_availability

    @Test func aFirstAvailabilityIsEverywhereByDefault() async throws {
        let outcome = try await call(ProposeAvailabilityTool(), ["appId": "Quiet Timer", "reason": "Sold worldwide."])
        #expect(status(outcome) == "queued")
        let change = try #require(changes.change(id: AppAvailabilityChangeBuilder.setupChangeID(appID: Self.quiet.id)))
        let setup = try #require(AppPriceAvailabilityRequests.availabilitySetup(in: Self.first(change.requests)))
        #expect(setup.isEverywhere)
        #expect(setup.availableInNewTerritories)
        #expect(change.source == .assistant(client: "Claude Code"))
    }

    @Test func aFirstAvailabilityCanBeSomeTerritories() async throws {
        let outcome = try await call(ProposeAvailabilityTool(), [
            "appId": "Quiet Timer", "territories": ["US", "Brazil"], "availableInNewTerritories": false,
        ])
        #expect(status(outcome) == "queued")
        let change = try #require(changes.change(id: AppAvailabilityChangeBuilder.setupChangeID(appID: Self.quiet.id)))
        let setup = try #require(AppPriceAvailabilityRequests.availabilitySetup(in: Self.first(change.requests)))
        #expect(setup.availableTerritoryIDs == ["USA", "BRA"])
        #expect(!setup.availableInNewTerritories)
    }

    @Test func aBadSetupIsRefused() async throws {
        let unknown = try await call(ProposeAvailabilityTool(), ["appId": "Quiet Timer", "territories": ["Atlantis"]])
        #expect(status(unknown) == "refused")
        let tooSoon = try await call(ProposeAvailabilityTool(), [
            "appId": "Quiet Timer", "preOrderReleaseDate": .string(AppAvailabilityRules.day(.now)),
        ])
        #expect(status(tooSoon) == "refused")
        #expect(changes.changes.isEmpty)
    }

    @Test func anExistingAvailabilityChangesPerTerritory() async throws {
        let outcome = try await call(ProposeAvailabilityTool(), [
            "appId": "Tempo Metronome", "makeAvailable": ["CHN"], "makeUnavailable": ["US", "BRA"], "reason": "Not localized yet.",
        ])
        #expect(status(outcome) == "queued")
        #expect(outcome.result.objectValue?["changeIds"]?.arrayValue?.count == 3)
        let china = try #require(changes.change(id: AppAvailabilityChangeBuilder.territoryChangeID(appID: Self.tempoID, territoryID: "CHN")))
        #expect(china.newValue == "Available")
        #expect(china.source == .assistant(client: "Claude Code"))
    }

    @Test func anExistingAvailabilityRefusesSetupArguments() async throws {
        let outcome = try await call(ProposeAvailabilityTool(), ["appId": "Tempo Metronome", "territories": "all"])
        #expect(status(outcome) == "refused")
    }

    @Test func aTerritoryAlreadyThatWayIsUnchanged() async throws {
        let outcome = try await call(ProposeAvailabilityTool(), ["appId": "Tempo Metronome", "makeAvailable": ["USA"]])
        #expect(status(outcome) == "unchanged")
        #expect(changes.changes.isEmpty)
    }
}
#endif
