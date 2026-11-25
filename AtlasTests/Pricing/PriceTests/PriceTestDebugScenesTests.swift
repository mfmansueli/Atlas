//
//  PriceTestDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 76's DEBUG scenes open and don't clash with Pricing's others.
@MainActor
@Suite("PriceTestDebugScenes")
struct PriceTestDebugScenesTests {
    @Test(arguments: PriceTestDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(PriceTestDebugScenes.view(for: id) != nil)
    }

    @Test func idsDontClashWithOtherPricingScenes() {
        let others = Set(PricesByCountryDebugScenes.ids + PricingConfidenceDebugScenes.ids + PricingDebugScenes.ids)
        #expect(others.isDisjoint(with: PriceTestDebugScenes.ids))
        #expect(Set(PriceTestDebugScenes.ids).count == PriceTestDebugScenes.ids.count)
    }

    @Test func theSampleRegionsAreAsOnTheBoard() {
        let europe = ["DEU", "FRA", "ESP", "ITA"].compactMap { DebugPriceTests.signals[$0] }.reduce(SalesSignal.zero, +)
        #expect(europe.pageViews == 2140)
        #expect(europe.starts == 96)
        let africa = ["ZAF", "ARE", "SAU"].compactMap { DebugPriceTests.signals[$0] }.reduce(SalesSignal.zero, +)
        #expect(africa.starts == 12)
    }
}
#endif
