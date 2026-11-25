//
//  PriceResultsTooFewTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 76: territories with too few to tell are listed after the others,
/// each with what it's short of.
@MainActor
@Suite("Price results · too few to tell")
struct PriceResultsTooFewTests {
    @Test func tooFewTerritoriesListAfterTheOthersWithTheirShortfall() async throws {
        let product = try PricingModelFixtures.annual()
        let services = DebugPricingServices(priceChanges: DebugPricingSales.readChanges(productID: product.id))
        let model = PriceResultsModel(appID: PricingModelFixtures.appID, product: product, services: services, queue: ChangeQueue())
        await model.load(records: [], today: PricingSampleData.date("2026-11-23"))
        #expect(model.tooFewResults.map(\.id) == ["PRT"])
        #expect(model.tableResults.map(\.id) == model.results.map(\.id) + ["PRT"])
        let portugal = try #require(model.tooFewResults.first)
        #expect(portugal.shortfall == .starts(5))
        #expect(portugal.shortfall?.text == "5 starts · needs 30")
        #expect(model.results.allSatisfy { $0.shortfall == nil })
    }

    @Test func thePillsReadAsTheDesignDraws() {
        #expect(ResultsReportView.pillStyle(.worse) == .warning)
        #expect(ResultsReportView.pillStyle(.tooLittleData) == .outline)
        #expect(ResultsReportView.pillStyle(.better) == .neutral)
        #expect(ResultsReportView.pillStyle(.aboutTheSame) == .neutral)
    }
}
#endif
