//
//  AnalyticsTabTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("Analytics · the views in the strip")
struct AnalyticsTabTests {
    @Test func theStripFollowsTheDesignsOrder() {
        #expect(AnalyticsTab.allCases == [.overview, .breakDown, .whatToTry, .afterChanges, .subscriptions, .stability])
        #expect(AnalyticsTab.allCases.map(\.title) == ["Overview", "Break It Down", "What to Try", "After Changes", "Subscriptions", "Stability"])
        #expect(AnalyticsTab.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
