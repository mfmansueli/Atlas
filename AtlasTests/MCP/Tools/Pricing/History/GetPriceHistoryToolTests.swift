//
//  GetPriceHistoryToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// get_price_history lists a product's price changes with their kept
/// windows and Results' verdict.
@MainActor
@Suite("get_price_history")
struct GetPriceHistoryToolTests {
    private typealias Fixtures = MCPPricingFixtures

    private static let pushedOn = PricingSampleData.date("2026-05-12")

    private static func record(
        _ territoryID: String, date: Date = pushedOn, origin: PriceHistoryOrigin = .pushed, before: SalesSignal? = nil, after: SalesSignal? = nil
    ) -> PriceChangeRecord {
        PriceChangeRecord(
            productID: Fixtures.annual, territoryID: territoryID, date: date, oldPrice: 249.9, newPrice: 219.9, currencyCode: "BRL",
            origin: origin, recordedOn: date, before: before, after: after
        )
    }

    private func read(_ arguments: [String: JSONValue] = [:], records: [PriceChangeRecord]) async throws -> MCPToolOutcome {
        var services = DebugPricingServices()
        services.priceChanges = records
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        arguments["productId"] = arguments["productId"] ?? .string(Fixtures.annual)
        return try await Fixtures.call(GetPriceHistoryTool(), arguments, pricing: services)
    }

    private func changes(_ outcome: MCPToolOutcome) throws -> [JSONValue] {
        try #require(outcome.result["products"]?.arrayValue?.first?["changes"]?.arrayValue)
    }

    @Test func aChangeWithAClearLiftIsBetter() async throws {
        let before = SalesSignal(pageViews: 2000, starts: 41, trialStarts: 41, proceeds: 300)
        let after = SalesSignal(pageViews: 2100, starts: 70, trialStarts: 70, proceeds: 500)
        let outcome = try await read(records: [Self.record("BRA", before: before, after: after)])

        let change = try #require(try changes(outcome).first)
        #expect(change["territory"] == "BRA")
        #expect(change["name"] == "Brazil")
        #expect(change["currency"] == "BRL")
        #expect(change["date"] == "2026-05-12")
        #expect(change["old"] == .double(249.9))
        #expect(change["new"] == .double(219.9))
        #expect(change["origin"] == "pushed")
        #expect(change["before"]?["starts"] == 41)
        #expect(change["after"]?["pageViews"] == 2100)
        #expect(change["verdict"] == "better")
        #expect(change["verdictTitle"] == "Better")
        #expect(change["resultsOn"] == nil)
        #expect(outcome.result["hint"]?.stringValue?.isEmpty == false)
        #expect(outcome.logLines == [.init(target: "Lumen Journal · Price history", outcome: .read)])
    }

    @Test func withoutKeptWindowsItsTooFewToTell() async throws {
        let outcome = try await read(records: [Self.record("DEU", origin: .read)])
        let change = try #require(try changes(outcome).first)
        #expect(change["verdict"] == "tooLittleData")
        #expect(change["verdictTitle"] == "Too few to tell")
        #expect(change["origin"] == "read")
        #expect(change["before"] == nil)
    }

    @Test func aRecentChangeSaysWhenItsResultArrives() async throws {
        let outcome = try await read(records: [Self.record("BRA", date: .now)])
        let change = try #require(try changes(outcome).first)
        #expect(change["resultsOn"] != nil)
        #expect(change["verdict"] == "tooLittleData")
    }

    @Test func newestFirstFilteredAndLimited() async throws {
        let records = [
            Self.record("BRA", date: PricingSampleData.date("2026-03-01")),
            Self.record("BRA", date: PricingSampleData.date("2026-06-01")),
            Self.record("DEU", date: PricingSampleData.date("2026-07-01")),
        ]
        let brazil = try await read(["territories": ["BR"]], records: records)
        #expect(try changes(brazil).map { $0["date"] } == ["2026-06-01", "2026-03-01"])

        let limited = try await read(["limit": 1], records: records)
        #expect(try changes(limited).count == 1)
        #expect(limited.result["products"]?.arrayValue?.first?["more"] == 2)
        #expect(limited.result["products"]?.arrayValue?.first?["count"] == 3)
    }

    @Test func noChangesSaysSo() async throws {
        let outcome = try await read(records: [])
        #expect(outcome.result["note"] != nil)
        #expect(try changes(outcome).isEmpty)
    }

    @Test func anUnknownTerritoryIsAnArgumentError() async throws {
        await #expect(throws: MCPToolError.invalidArgument(name: "territories", expected: "territory codes such as BRA or BR, or names")) {
            try await read(["territories": ["Atlantis"]], records: [])
        }
    }

    @Test func theToolIsServedAndReadOnly() {
        #expect(MCPToolbox.standard.toolNames.contains("get_price_history"))
        #expect(GetPriceHistoryTool().definition.description.contains("Read-only"))
    }
}
#endif
