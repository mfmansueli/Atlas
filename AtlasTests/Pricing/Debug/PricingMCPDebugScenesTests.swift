//
//  PricingMCPDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The propose_prices DEBUG scene opens, with what the tool attaches.
@MainActor
@Suite("PricingMCPDebugScenes")
struct PricingMCPDebugScenesTests {
    @Test(arguments: PricingMCPDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(PricingMCPDebugScenes.view(for: id) != nil)
    }

    @Test func idsDontClashWithOtherPricingScenes() {
        let others = Set(PricingConfidenceDebugScenes.ids + PricesByCountryDebugScenes.ids + PricingDebugScenes.ids)
        #expect(others.isDisjoint(with: PricingMCPDebugScenes.ids))
    }

    @Test func theChangesCarryEvidenceAndHowSure() {
        let changes = PricingMCPDebugScenes.changes
        #expect(changes.map(\.title) == ["Brazil", "India"])
        #expect(changes.map { $0.layers?.confidence } == [.notVerySure, .fairlySure])
        #expect(changes.allSatisfy { $0.layers?.details?.hasPrefix("Based on: ") == true })
        #expect(changes.allSatisfy { $0.source == .assistant(client: "Claude Code") })
    }
}
#endif
