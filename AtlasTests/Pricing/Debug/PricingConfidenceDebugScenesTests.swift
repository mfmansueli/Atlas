//
//  PricingConfidenceDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// HowSure's DEBUG scenes open, and their sample sales say what each
/// scene is for.
@MainActor
@Suite("PricingConfidenceDebugScenes")
struct PricingConfidenceDebugScenesTests {
    @Test(arguments: PricingConfidenceDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(PricingConfidenceDebugScenes.view(for: id) != nil)
    }

    @Test func idsDontClashWithOtherPricingScenes() {
        let others = Set(PricesByCountryDebugScenes.ids + PricesByCountryPageDebugScenes.ids + PricingDebugScenes.ids)
        #expect(others.isDisjoint(with: PricingConfidenceDebugScenes.ids))
    }

    private func sheet(_ scenario: DebugPricingConfidenceSales.Scenario) throws -> ProductPriceSheet {
        let product = try PricingModelFixtures.annual()
        let sheet = DebugPriceSheets.sheet(for: product, commission: .smallBusiness, canReadSales: true)
        return DebugPricingConfidenceSales.sheet(sheet, scenario: scenario, commission: .smallBusiness)
    }

    @Test func noSalesIsAlbaLike() throws {
        let sales = try sheet(.noSales).sales
        #expect(sales.availability == .noSalesYet)
        #expect(sales.signals.values.reduce(0) { $0 + $1.pageViews } == 79)
        #expect(sales.signals.values.allSatisfy { $0.starts == 0 })
    }

    @Test func portugalBorrowsFromEurope() throws {
        let sales = try sheet(.thin).sales
        let estimate = try #require(sales.pooling().estimate(for: "PRT"))
        #expect(estimate.leansOnRegion)
        #expect(!PriceConfidenceRule.meetsSample(estimate.own, usesTrials: true))
        #expect(PriceConfidenceRule.meetsSample(estimate.regionTotal, usesTrials: true))
    }

    @Test func sureChangesHaveAClearLift() throws {
        let sales = try sheet(.sure).sales
        #expect(sales.priorChanges.count == 5)
        for change in sales.priorChanges.values {
            #expect(PriorChangeEffect(before: change.before, after: change.after)?.excludesZero == true)
            #expect(change.before.starts >= PriceConfidenceRule.minimumStartsEachSide)
        }
    }

    @Test func theSnapshotCountsAsPublished() {
        let snapshot = DebugPricingConfidenceSales.snapshot
        #expect(!snapshot.isApproximate)
        #expect(snapshot.trust(of: .worldBank, territoryID: "BRA", asOf: DebugPricingConfidenceSales.readThrough).countsAsReal)
    }
}
#endif
