//
//  GetPriceTestsToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// get_price_tests reads the tests and the cards waiting; it changes
/// nothing.
@MainActor
@Suite("get_price_tests")
struct GetPriceTestsToolTests {
    private typealias Fixtures = MCPPricingFixtures

    private func read(_ store: PriceTestStore) async throws -> MCPToolOutcome {
        let tool = GetPriceTestsTool(now: { PriceTestFixtures.today }, store: { store })
        return try await Fixtures.call(tool, ["appId": .string(Fixtures.lumen)])
    }

    @Test func aRunningTestSaysItsDay() async throws {
        let store = PriceTestStore()
        store.update(Fixtures.lumen) { $0.tests = [PriceTestFixtures.test()] }
        let outcome = try await read(store)
        let test = try #require(outcome.result["tests"]?.arrayValue?.first)
        #expect(test["region"] == "europe")
        #expect(test["state"] == "running")
        #expect(test["phase"] == "running")
        #expect(test["day"] == 9)
        #expect(test["comparison"] == "asiaPacific")
        #expect(test["endsOn"] == "2026-12-15")
        #expect(test["result"] == nil)
        #expect(outcome.logLines.first?.outcome == .read)
    }

    @Test func aQueuedTestOutOfReviewAndPushIsLeftOut() async throws {
        let store = PriceTestStore()
        store.update(Fixtures.lumen) { $0.tests = [PriceTestFixtures.test(state: .queued, startedOn: nil)] }
        let outcome = try await read(store)
        #expect(outcome.result["tests"]?.arrayValue?.isEmpty == true)
        #expect(outcome.result["note"] != nil)
    }

    @Test func aReadTestHasItsVerdict() async throws {
        var test = PriceTestFixtures.test(startedOn: PricingSampleData.date("2026-10-20"))
        test.windows = PriceTestWindows(
            testBefore: PriceTestFixtures.signal(2000, 80, proceeds: 1000),
            testDuring: PriceTestFixtures.signal(2000, 140, proceeds: 1500),
            controlBefore: PriceTestFixtures.signal(2000, 80, proceeds: 1000),
            controlDuring: PriceTestFixtures.signal(2000, 80, proceeds: 1000),
            readOn: PriceTestFixtures.today
        )
        let store = PriceTestStore()
        store.update(Fixtures.lumen) { $0.tests = [test] }
        let result = try #require(try await read(store).result["tests"]?.arrayValue?.first?["result"])
        #expect(result["verdict"] == "better")
        #expect(result["howSure"] == "Sure")
        #expect(result["points"] == .double(3))
    }
}
#endif
