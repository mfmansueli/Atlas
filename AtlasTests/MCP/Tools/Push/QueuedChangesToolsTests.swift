//
//  QueuedChangesToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_queued_changes` and `withdraw_changes`: what waits in Review &
/// Push, and an assistant taking its own changes back out.
@MainActor
@Suite("get_queued_changes and withdraw_changes")
struct QueuedChangesToolsTests {
    private typealias Fixtures = MCPPricingFixtures
    private let changes = ChangeQueue()

    private func queueMineAndThePersons() async throws {
        _ = try await Fixtures.call(
            ProposePricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "territory": "BRA", "price": .double(109.9)],
            changes: changes
        )
        try changes.upsert(Fixtures.personsChange("IND", to: "99"))
    }

    private func list(_ arguments: [String: JSONValue] = [:]) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        return try await Fixtures.call(GetQueuedChangesTool(), arguments, changes: changes)
    }

    private func withdraw(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = .string(Fixtures.lumen)
        return try await Fixtures.call(WithdrawChangesTool(), arguments, changes: changes)
    }

    // MARK: - Reading

    @Test func listsEveryChangeWithWhoProposedIt() async throws {
        try await queueMineAndThePersons()
        let outcome = try await list()

        #expect(outcome.result["count"] == 2)
        let rows = try #require(outcome.result["changes"]?.arrayValue)
        let brazil = try #require(rows.first { $0["changeId"] == .string(Fixtures.changeID("BRA")) })
        #expect(brazil["mine"] == true)
        #expect(brazil["by"] == .string(Fixtures.client))
        #expect(brazil["from"] == "R$ 219,90")
        #expect(brazil["to"] == "R$ 109,90")
        #expect(brazil["section"] == "subscriptionPricing")
        #expect(brazil["status"] == "ready")
        let india = try #require(rows.first { $0["changeId"] == .string(Fixtures.changeID("IND")) })
        #expect(india["mine"] == false)
        #expect(india["by"] == "You")
        #expect(outcome.logLines.first?.outcome == .read)
    }

    @Test func filtersByMineAndSection() async throws {
        try await queueMineAndThePersons()
        #expect(try await list(["mine": true]).result["count"] == 1)
        #expect(try await list(["section": "storePage"]).result["count"] == 0)
        #expect(try await list(["section": "Subscription Pricing"]).result["count"] == 2)
        await #expect(throws: MCPToolError.self) { try await list(["section": "nowhere"]) }
    }

    @Test func aLimitSaysHowManyMore() async throws {
        try await queueMineAndThePersons()
        let outcome = try await list(["limit": 1])
        #expect(outcome.result["changes"]?.arrayValue?.count == 1)
        #expect(outcome.result["more"] == 1)
    }

    @Test func twoVersionsNeedADecision() async throws {
        try changes.upsert(Fixtures.personsChange("BRA", to: "99.90"))
        _ = try await Fixtures.call(
            ProposePricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "territory": "BRA", "price": .double(109.9)],
            changes: changes
        )
        let row = try #require(try await list().result["changes"]?.arrayValue?.first)
        #expect(row["status"] == "needsDecision")
        #expect(row["alternative"]?["mine"] == true)
        #expect(row["alternative"]?["to"] == "R$ 109,90")
    }

    // MARK: - Withdrawing

    @Test func withdrawsYoursAndLeavesThePersons() async throws {
        try await queueMineAndThePersons()
        let outcome = try await withdraw(["changeIds": .array([.string(Fixtures.changeID("BRA")), .string(Fixtures.changeID("IND")), "nope"])])

        #expect(outcome.result["withdrawn"]?.arrayValue?.count == 1)
        let left = try #require(outcome.result["left"]?.arrayValue)
        #expect(left.compactMap { $0["changeId"]?.stringValue } == [Fixtures.changeID("IND"), "nope"])
        #expect(changes.change(id: Fixtures.changeID("BRA")) == nil)
        #expect(changes.change(id: Fixtures.changeID("IND")) != nil)
        #expect(outcome.logLines.first?.outcome == .proposed)
    }

    @Test func withdrawingYourVersionKeepsThePersons() async throws {
        try changes.upsert(Fixtures.personsChange("BRA", to: "99.90"))
        _ = try await Fixtures.call(
            ProposePricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "territory": "BRA", "price": .double(109.9)],
            changes: changes
        )
        let outcome = try await withdraw(["changeId": .string(Fixtures.changeID("BRA"))])
        #expect(outcome.result["withdrawn"]?.arrayValue?.first?["alternative"] == true)
        let change = try #require(changes.change(id: Fixtures.changeID("BRA")))
        #expect(change.source == .you)
        #expect(change.alternative == nil)
    }

    @Test func allOfYoursInASection() async throws {
        try await queueMineAndThePersons()
        let none = try await withdraw(["all": true, "section": "storePage"])
        #expect(none.result["withdrawn"] == [])
        let outcome = try await withdraw(["all": true, "section": "subscriptionPricing"])
        #expect(outcome.result["withdrawn"]?.arrayValue?.count == 1)
        #expect(changes.changes.map(\.id) == [Fixtures.changeID("IND")])
    }

    @Test func aWithdrawnPriceLeavesTheProductsRowLine() async throws {
        let prices: [JSONValue] = [["territory": "BRA", "price": .double(109.9)], ["territory": "MEX", "automatic": true]]
        _ = try await Fixtures.call(
            ProposePricesTool(),
            ["appId": .string(Fixtures.lumen), "productId": .string(Fixtures.annual), "prices": .array(prices)],
            changes: changes
        )
        _ = try await withdraw(["changeId": .string(Fixtures.changeID("BRA"))])
        let mexico = try #require(changes.change(id: Fixtures.changeID("MEX")))
        #expect(mexico.creation?.detail.contains("Brazil") == false)
        #expect(mexico.creation?.detail.contains("Mexico") == true)
    }

    @Test func anIDIsNeeded() async throws {
        await #expect(throws: MCPToolError.self) { try await withdraw([:]) }
    }

    @Test func theToolsAreRegistered() {
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: ["get_queued_changes", "withdraw_changes"]))
        #expect(MCPEndpoint.instructions.contains("withdraw_changes"))
        #expect(MCPEndpoint.instructions.contains("propose_price_schedule"))
        #expect(GetQueuedChangesTool().definition.isReadOnly)
        #expect(!WithdrawChangesTool().definition.isReadOnly)
    }
}
#endif
