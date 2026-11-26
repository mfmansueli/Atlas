//
//  ReviewPushOpeningTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which tab Review & Push opens on: To Push while changes wait, Activity
/// when nothing does, and the one asked for by ⌘Y or Show in Activity.
@MainActor
@Suite("Review & Push · opening tab")
struct ReviewPushOpeningTests {
    @Test func itOpensOnActivityWhenNothingWaits() {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.pendingReviewCount = { 0 }
        navigator.isReviewPresented = true
        #expect(navigator.reviewTab == .activity)
    }

    @Test func itOpensOnToPushWhenChangesWait() {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.pendingReviewCount = { 5 }
        navigator.reviewTab = .activity
        navigator.isReviewPresented = true
        #expect(navigator.reviewTab == .toPush)
    }

    @Test func anAskedTabWins() {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.pendingReviewCount = { 0 }
        navigator.openReview(on: .toPush)
        #expect(navigator.reviewTab == .toPush)
        navigator.isReviewPresented = false
        navigator.reviewDidClose()
        navigator.pendingReviewCount = { 4 }
        navigator.openActivity()
        #expect(navigator.reviewTab == .activity)
    }

    @Test func closingClearsTheHighlight() {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.openActivity(highlighting: UUID())
        navigator.isReviewPresented = false
        navigator.reviewDidClose()
        #expect(navigator.highlightedPushID == nil)
        navigator.pendingReviewCount = { 2 }
        navigator.isReviewPresented = true
        #expect(navigator.reviewTab == .toPush, "the next opening chooses again")
    }
}
