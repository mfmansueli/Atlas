//
//  ReviewPushTabTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Review & Push · its tabs")
struct ReviewPushTabTests {
    @Test func opensOnActivityWhenNothingWaits() {
        #expect(ReviewPushTab.opening(pendingCount: 0) == .activity)
        #expect(ReviewPushTab.opening(pendingCount: 3) == .toPush)
    }

    @MainActor
    @Test func openActivityHighlightsThePush() {
        let navigator = WorkspaceNavigator(section: .overview)
        let id = UUID()
        navigator.openActivity(highlighting: id)
        #expect(navigator.reviewTab == .activity)
        #expect(navigator.highlightedPushID == id)
        #expect(navigator.isReviewPresented)
    }
}
