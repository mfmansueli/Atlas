//
//  PricingDecisionsDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Board 76's DEBUG scenes open, don't clash with other ids, and their
/// Results samples are short of what they say.
@MainActor
@Suite("PricingDecisionsDebugScenes")
struct PricingDecisionsDebugScenesTests {
    @Test(arguments: PricingDecisionsDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(PricingDecisionsDebugScenes.view(for: id) != nil)
    }

    @Test func idsDontClashWithOtherScenes() {
        let others = Set(
            PricesByCountryDebugScenes.ids + PricesByCountryPageDebugScenes.ids + PricingDebugScenes.ids + PricingConfidenceDebugScenes.ids
                + SettingsDebugScenes.ids
        )
        #expect(others.isDisjoint(with: PricingDecisionsDebugScenes.ids))
    }

    @Test func theResultsSamplesAreShortOfWhatTheySay() {
        let starts = PricingDecisionsDebugScenes.portugalShortOfStarts
        #expect(ResultShortfall.of(before: starts.before, after: starts.after)?.text == "12 starts · needs 30")
        let views = PricingDecisionsDebugScenes.portugalShortOfPageViews
        #expect(ResultShortfall.of(before: views.before, after: views.after)?.text == "64 page views · needs 100")
    }
}
#endif
