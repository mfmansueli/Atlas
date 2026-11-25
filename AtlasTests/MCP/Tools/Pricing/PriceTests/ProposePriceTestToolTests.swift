//
//  ProposePriceTestToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// propose_price_test leaves a card; the assistant never starts, changes
/// or ends a test, and its words follow Atlas's voice.
@MainActor
@Suite("propose_price_test")
struct ProposePriceTestToolTests {
    private typealias Fixtures = MCPPricingFixtures

    private static let today = PricingSampleData.date("2026-11-25")

    private func propose(
        _ extra: [String: JSONValue] = [:],
        store: PriceTestStore,
        productID: String = Fixtures.annual
    ) async throws -> MCPToolOutcome {
        var arguments: [String: JSONValue] = [
            "appId": .string(Fixtures.lumen),
            "productId": .string(productID),
            "region": "europe",
            "step": "-20",
            "title": "Test 20% lower prices in Europe",
            "why": "Europe converts 4.5% of page views, under the 6% of your other regions.",
        ]
        arguments.merge(extra) { _, new in new }
        let tool = ProposePriceTestTool(now: { Self.today }, store: { store })
        return try await Fixtures.call(tool, arguments)
    }

    @Test func aSuggestionWaitsAsACard() async throws {
        let store = PriceTestStore()
        let outcome = try await propose(store: store)
        #expect(outcome.result["status"] == "suggested")
        let suggestion = try #require(store.book(for: Fixtures.lumen).suggestions.first)
        #expect(suggestion.region == .europe)
        #expect(suggestion.step == .percent(-20))
        #expect(suggestion.source == Fixtures.client)
        #expect(store.tests(for: Fixtures.lumen).isEmpty)
        #expect(outcome.logLines.first?.outcome == .proposed)
    }

    @Test(arguments: ["start", "end", "stop", "change", "testId", "action"])
    func actingOnATestIsRefused(argument: String) async throws {
        let store = PriceTestStore()
        let outcome = try await propose([argument: .bool(true)], store: store)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("only the person starts, changes or ends a price test") == true)
        #expect(store.book(for: Fixtures.lumen).suggestions.isEmpty)
    }

    @Test(arguments: [
        ("title", "Test lower prices in Europe to win more people over"),
        ("title", "Test lower prices!"),
        ("why", "Just try it."),
        ("why", String(repeating: "Europe converts few page views. ", count: 5)),
    ])
    func wordsOutsideAtlassVoiceAreRefused(field: String, text: String) async throws {
        let outcome = try await propose([field: .string(text)], store: PriceTestStore())
        #expect(outcome.result["status"] == "refused")
    }

    @Test func inAppPurchasesAreRefused() async throws {
        let outcome = try await propose(store: PriceTestStore(), productID: Fixtures.lifetime)
        #expect(outcome.result["status"] == "refused")
    }

    @Test func aRegionInATestIsRefused() async throws {
        let store = PriceTestStore()
        store.update(Fixtures.lumen) { $0.tests = [PriceTestFixtures.test(region: .europe)] }
        let outcome = try await propose(store: store)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.hasSuffix("one test per region at a time.") == true)
    }

    @Test func anUnknownRegionOrStepIsAnError() async throws {
        await #expect(throws: MCPToolError.self) { try await propose(["region": "antarctica"], store: PriceTestStore()) }
        await #expect(throws: MCPToolError.self) { try await propose(["step": "-15"], store: PriceTestStore()) }
    }

    @Test(arguments: ["europe", "Europe", "asiaPacific", "Asia Pacific", "africaMiddleEast", "Africa & Middle East", "americas"])
    func regionsReadEitherWay(text: String) {
        #expect(PriceTestProposalCheck.region(text) != nil)
    }

    @Test func withdrawTakesTheCardBack() async throws {
        let store = PriceTestStore()
        _ = try await propose(store: store)
        let outcome = try await propose(["withdraw": .bool(true)], store: store)
        #expect(outcome.result["status"] == "withdrawn")
        #expect(store.book(for: Fixtures.lumen).suggestions.isEmpty)
    }

    @Test func aNewSuggestionForTheRegionReplacesYours() async throws {
        let store = PriceTestStore()
        _ = try await propose(store: store)
        _ = try await propose(["step": "-10"], store: store)
        let suggestions = store.book(for: Fixtures.lumen).suggestions
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.step == .percent(-10))
    }

    @Test func bothToolsAreListedAndTheInstructionsSayWho() {
        #expect(MCPToolbox.standard.toolNames.contains("propose_price_test"))
        #expect(MCPToolbox.standard.toolNames.contains("get_price_tests"))
        #expect(MCPEndpoint.instructions.contains("you never start, change or end a test"))
        #expect(MCPEndpoint.instructions.contains("price test. Never:"))
    }
}
#endif
