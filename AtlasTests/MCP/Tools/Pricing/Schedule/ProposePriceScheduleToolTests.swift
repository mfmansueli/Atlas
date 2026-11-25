//
//  ProposePriceScheduleToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("propose_price_schedule")
struct ProposePriceScheduleToolTests {
    private typealias Fixtures = MCPPricingFixtures
    private let changes = ChangeQueue()
    /// 25 Nov 2026, noon in the Mac's calendar.
    private let today = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12)) ?? .now

    private func schedule(_ arguments: [String: JSONValue], product: String = Fixtures.annual) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        arguments["productId"] = .string(product)
        let today = today
        return try await Fixtures.call(ProposePriceScheduleTool(now: { today }), arguments, changes: changes)
    }

    private func queueTwoPrices() async throws {
        let prices: [JSONValue] = [["territory": "BRA", "price": .double(109.9)], ["territory": "USA", "price": .double(44.99)]]
        _ = try await Fixtures.call(
            ProposePricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "prices": .array(prices)],
            changes: changes
        )
    }

    @Test func aStartDayGoesOnEveryPriceChange() async throws {
        try await queueTwoPrices()
        try changes.upsert(Fixtures.personsChange("IND", to: "99"))

        let outcome = try await schedule(["startDate": "2026-12-01", "preserveCurrentPrice": false])

        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["changes"] == 3)
        #expect(outcome.result["startDate"] == "2026-12-01")
        let expected = PriceSchedule(startDay: "2026-12-01", preservesCurrentPrice: false)
        for id in ["BRA", "USA", "IND"] {
            let change = try #require(changes.change(id: Fixtures.changeID(id)))
            #expect(PriceSchedule(change: change) == expected)
            #expect(change.groupNote == expected.note)
        }
        let increases = try #require(outcome.result["increases"]?.arrayValue)
        let raised = increases.compactMap { $0["territory"]?.stringValue }
        #expect(raised.contains("USA"))
        #expect(!raised.contains("BRA"))
    }

    @Test func nowAndTheSameScheduleAgain() async throws {
        try await queueTwoPrices()
        _ = try await schedule(["startDate": "2026-12-01"])
        let now = try await schedule(["startDate": "now"])
        #expect(now.result["status"] == "queued")
        let brazil = try #require(changes.change(id: Fixtures.changeID("BRA")))
        #expect(PriceSchedule(change: brazil) == .immediate)
        let again = try await schedule([:])
        #expect(again.result["status"] == "unchanged")
    }

    @Test func aDayBeforeTomorrowOrNotADayIsRefused() async throws {
        try await queueTwoPrices()
        await #expect(throws: MCPToolError.self) { try await schedule(["startDate": "2026-11-25"]) }
        await #expect(throws: MCPToolError.self) { try await schedule(["startDate": "December 1"]) }
        await #expect(throws: MCPToolError.self) { try await schedule(["startDate": "2026-02-30"]) }
        #expect(try ProposePriceScheduleTool.startDay("2026-11-26", today: today) == "2026-11-26")
    }

    @Test func nothingWaitingIsRefused() async throws {
        let outcome = try await schedule(["startDate": "2026-12-01"])
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("propose_prices") == true)
    }

    @Test func anInAppPurchaseHasNoSchedule() async throws {
        let outcome = try await schedule(["startDate": "2026-12-01"], product: Fixtures.lifetime)
        #expect(outcome.result["status"] == "refused")
    }

    @Test func theToolIsRegistered() {
        #expect(MCPToolbox.standard.tool(named: "propose_price_schedule") != nil)
        #expect(ProposePriceScheduleTool().definition.proposalKind == .prices)
    }
}
#endif
