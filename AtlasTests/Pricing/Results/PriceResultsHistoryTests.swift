//
//  PriceResultsHistoryTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Results from the price history: a change read from App Store Connect,
/// compared with its kept 28-day windows.
@MainActor
@Suite("Price results from the history")
struct PriceResultsHistoryTests {
    @Test func aReadChangeIsComparedWithoutRestore() async throws {
        let product = try PricingModelFixtures.annual()
        let services = DebugPricingServices(priceChanges: DebugPricingSales.readChanges(productID: product.id))
        let model = PriceResultsModel(appID: PricingModelFixtures.appID, product: product, services: services, queue: ChangeQueue())
        await model.load(records: [], today: PricingSampleData.date("2026-11-23"))
        #expect(model.state == .ready(changedOn: DebugPricingSales.readChangeDate))
        let verdicts = Dictionary(uniqueKeysWithValues: model.results.map { ($0.id, $0.verdict) })
        #expect(verdicts == ["BRA": .better, "JPN": .worse, "DEU": .aboutTheSame])
        #expect(model.summary?.tooLittleDataCount == 1)
        let japan = try #require(model.results.first { $0.id == "JPN" })
        #expect(!model.canRestore(japan))
    }

    @Test func tooEarlyBefore28Days() async throws {
        let product = try PricingModelFixtures.annual()
        let services = DebugPricingServices(priceChanges: DebugPricingSales.readChanges(productID: product.id))
        let model = PriceResultsModel(appID: PricingModelFixtures.appID, product: product, services: services, queue: ChangeQueue())
        await model.load(records: [], today: PricingSampleData.date("2026-10-30"))
        guard case let .tooEarly(changedOn, day, _) = model.state else {
            Issue.record("Expected too early, got \(model.state)")
            return
        }
        #expect(changedOn == DebugPricingSales.readChangeDate)
        #expect(day == 11)
    }

    @Test func nothingChangedIsNoChanges() async throws {
        let model = try PriceResultsModel(
            appID: PricingModelFixtures.appID, product: PricingModelFixtures.annual(), services: DebugPricingServices(), queue: ChangeQueue()
        )
        await model.load(records: [], today: .now)
        #expect(model.state == .noChanges)
    }

    @Test func theSamplePushsJapanIsWorseAndRestorable() async throws {
        let product = try PricingModelFixtures.annual()
        let push = try #require(DebugPricingResults.annualPush())
        let model = PriceResultsModel(appID: PricingModelFixtures.appID, product: product, services: DebugPricingServices(), queue: ChangeQueue())
        await model.load(records: [push], today: PricingSampleData.date("2026-11-23"))
        let japan = try #require(model.results.first { $0.id == "JPN" })
        #expect(japan.verdict == .worse)
        #expect(model.canRestore(japan))
    }
}
#endif
