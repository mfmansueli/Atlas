//
//  ReviewPushPillStateTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Review & Push at the bottom (board 80): “Up to Date” with nothing, blue
/// with the count, “Pushing · 14 of 23” while a push runs, and icon and
/// count only under 700 pt.
@Suite("ReviewPushPillState")
struct ReviewPushPillStateTests {
    @Test func nothingWaitingIsUpToDate() {
        let state = ReviewPushPillState(count: 0, sending: nil)
        #expect(state == .upToDate)
        #expect(!state.isProminent)
        #expect(state.title == "Up to Date")
        #expect(state.badge(isCompact: false) == nil)
        #expect(state.badge(isCompact: true) == nil)
        #expect(state.accessibilityValue == "Up to date")
    }

    @Test func changesWaitingAreBlueWithTheirCount() {
        let state = ReviewPushPillState(count: 3, sending: nil)
        #expect(state == .pending(3))
        #expect(state.isProminent)
        #expect(state.title == "Review & Push")
        #expect(state.badge(isCompact: false) == "3")
        #expect(state.badge(isCompact: true) == "3", "Folded, the count stays")
        #expect(state.accessibilityValue == "3 changes ready")
        #expect(ReviewPushPillState.pending(1).accessibilityValue == "1 change ready")
        #expect(state.help == "Review & Push (⇧⌘P)")
    }

    @Test func aPushSaysHowManyWereSent() {
        let state = ReviewPushPillState(count: 9, sending: (sent: 14, total: 23))
        #expect(state == .pushing(sent: 14, total: 23), "A running push wins over what still waits")
        #expect(state.isProminent)
        #expect(state.title == "Pushing · 14 of 23")
        #expect(state.badge(isCompact: false) == nil, "The title already counts")
        #expect(state.badge(isCompact: true) == "14/23")
        #expect(state.accessibilityValue == "Pushing 14 of 23")
        #expect(state.count == 14)
    }

    @Test func aPushWithNothingLeftStillSaysPushing() {
        #expect(ReviewPushPillState(count: 0, sending: (sent: 0, total: 5)) == .pushing(sent: 0, total: 5))
    }

    @Test func itFoldsOnlyUnder700PointsOfWindow() {
        #expect(!ReviewPushPillState.isCompact(windowWidth: 0), "Not before the window is measured")
        #expect(ReviewPushPillState.isCompact(windowWidth: 699))
        #expect(!ReviewPushPillState.isCompact(windowWidth: 700))
        #expect(!ReviewPushPillState.isCompact(windowWidth: Metrics.minimumWindowWidth))
    }
}
