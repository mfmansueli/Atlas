//
//  PriceGridGateTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// No suggestion on a simulated grid: rows suggest only where Apple's own
/// points are here, the matrix says "Checking Apple’s prices…" until they
/// are, and a failed read suggests nothing and says why.
@MainActor
@Suite("Pricing · suggestions wait for Apple's price points")
struct PriceGridGateTests {
    private typealias Fixtures = PricingModelFixtures

    private func simulatedSheet() throws -> ProductPriceSheet {
        var sheet = try DebugPriceSheets.sheet(for: Fixtures.annual(), commission: Fixtures.commission, canReadSales: true)
        sheet.exactLadderIDs = []
        return sheet
    }

    private func builder(_ sheet: ProductPriceSheet, strategy: PricingStrategy = .recommended) -> PricingRowBuilder {
        PricingRowBuilder(
            catalog: .standard,
            calculator: PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: Fixtures.commission),
            sheet: sheet,
            strategy: strategy,
            showsSuggestions: true
        )
    }

    private func matrix(_ services: DebugPricingServices) throws -> PriceMatrixModel {
        try PriceMatrixModel(
            appID: Fixtures.appID,
            product: Fixtures.annual(),
            sheet: simulatedSheet(),
            services: services,
            queue: ChangeQueue(),
            strategy: .recommended,
            calculator: PriceCalculator(snapshot: PricingSampleData.shared.snapshot, commission: Fixtures.commission),
            mode: .showSuggestions
        )
    }

    // MARK: - Builder

    @Test func aSimulatedGridSuggestsNothing() throws {
        let builder = try builder(simulatedSheet())
        #expect(builder.recommendations().isEmpty)
        #expect(!builder.rows().contains { $0.hasSuggestion })
    }

    @Test func aCustomStrategyDoesntMoveSimulatedPricesEither() throws {
        let builder = try builder(simulatedSheet(), strategy: Fixtures.premiumStrategy)
        #expect(!builder.rows().contains { $0.hasSuggestion })
    }

    @Test func onlyTerritoriesWithApplesPointsSuggest() throws {
        var sheet = try simulatedSheet()
        let real = try DebugPriceSheets.sheet(for: Fixtures.annual(), commission: Fixtures.commission, canReadSales: true)
        sheet.exactLadderIDs = ["BRA", "IND"]
        let recommendations = builder(sheet).recommendations()
        #expect(Set(recommendations.keys).isSubset(of: ["BRA", "IND"]))
        // The full sheet suggests in more places than the two.
        #expect(builder(real).recommendations().count > recommendations.count)
    }

    @Test func aGridStillBeingReadSuggestsNothing() throws {
        var builder = try builder(DebugPriceSheets.sheet(for: Fixtures.annual(), commission: Fixtures.commission, canReadSales: true))
        #expect(builder.rows().contains { $0.hasSuggestion })
        builder.isGridReady = false
        #expect(builder.recommendations().isEmpty)
        #expect(!builder.rows().contains { $0.hasSuggestion })
    }

    @Test func aNewSubscriptionSuggestsWithoutAGrid() throws {
        var builder = try builder(simulatedSheet())
        builder.requiresRealGrid = false
        #expect(!builder.recommendations().isEmpty)
    }

    // MARK: - Matrix

    @Test func theMatrixChecksUntilThePointsArrive() async throws {
        let services = DebugPricingServices(simulatesGrid: true)
        let matrix = try matrix(services)
        #expect(matrix.grid == .checking)
        #expect(matrix.isCheckingGrid)
        #expect(!matrix.rows.contains { $0.hasSuggestion })
        // Today's prices show meanwhile.
        #expect(!matrix.rows.isEmpty)

        await matrix.loadGrid()
        #expect(matrix.grid == .ready)
        #expect(matrix.rows.contains { $0.hasSuggestion })
        #expect(services.calls.ladderRequests.count == 1)
    }

    @Test func callersWhileItReadsShareOneRead() async throws {
        var services = DebugPricingServices(simulatesGrid: true)
        services.laddersDelay = .milliseconds(50)
        let matrix = try matrix(services)
        async let first: Void = matrix.loadGrid()
        async let second: Void = matrix.loadGrid()
        _ = await (first, second)
        #expect(services.calls.ladderRequests.count == 1)
        await matrix.loadGrid()
        #expect(services.calls.ladderRequests.count == 1)
    }

    @Test func aFailedReadSuggestsNothingAndSaysWhy() async throws {
        var services = DebugPricingServices(simulatesGrid: true)
        services.laddersError = .server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: "An unexpected error occurred on the server side.")
        let matrix = try matrix(services)
        await matrix.loadGrid()
        let failure = try #require(matrix.gridFailure)
        #expect(failure.hasPrefix(PriceGridState.failureTitle))
        #expect(!failure.contains("UNEXPECTED_ERROR"))
        #expect(!matrix.rows.contains { $0.hasSuggestion })
    }

    @Test func keepMyPricesReadsNoGrid() throws {
        let services = DebugPricingServices(simulatesGrid: true)
        let matrix = try matrix(services)
        matrix.update(mode: .keepPrices)
        #expect(!matrix.needsGrid)
        #expect(!matrix.isCheckingGrid)
    }

    @Test func followingReadsTheWholeGridFirst() async throws {
        let services = DebugPricingServices(simulatesGrid: true)
        let matrix = try matrix(services)
        await matrix.follow()
        #expect(matrix.grid == .ready)
        #expect(matrix.pendingCount > 0)
    }
}
#endif
