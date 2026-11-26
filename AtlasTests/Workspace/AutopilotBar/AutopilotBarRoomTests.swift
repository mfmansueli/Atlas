//
//  AutopilotBarRoomTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The room the closed Autopilot bar takes at the bottom of every page
/// (board 80), and how tall it may grow open: never to the toolbar.
@Suite("Autopilot bar · room")
struct AutopilotBarRoomTests {
    @Test func aPageEndsAboveTheClosedField() {
        let fieldTop = AutopilotBarRoom.bottomInset + Metrics.autopilotBarFieldHeight
        #expect(AutopilotBarRoom.pageRoom == fieldTop + AutopilotBarRoom.gap)
        #expect(AutopilotBarRoom.pageRoom == 64)
    }

    @Test func aStripGrowsTheRoom() {
        #expect(AutopilotBarRoom.room(closedHeight: 100) == AutopilotBarRoom.bottomInset + 100 + AutopilotBarRoom.gap)
        // Never less than the field.
        #expect(AutopilotBarRoom.room(closedHeight: 0) == AutopilotBarRoom.pageRoom)
    }

    @Test func openItGrowsUpToItsHeightAndNeverToTheTop() {
        #expect(AutopilotBarRoom.openHeight(in: 900) == Metrics.autopilotBarOpenHeight)
        // At 860 × 560 the content is 508 tall: it stops 8 under the toolbar.
        let content = Metrics.minimumWindowHeight - Metrics.windowToolbarHeight
        #expect(AutopilotBarRoom.openHeight(in: content) == Metrics.autopilotBarOpenHeight)
        #expect(AutopilotBarRoom.openHeight(in: 300) == 300 - AutopilotBarRoom.bottomInset - AutopilotBarRoom.topClearance)
        #expect(AutopilotBarRoom.openHeight(in: 0) == Metrics.autopilotBarFieldHeight)
    }

    @Test func theBarAndReviewAndPushFitTheNarrowestColumn() {
        // 860 − the 256 pt sidebar: the dock's sides leave the bar room
        // for its field's words and More.
        let column = Metrics.minimumWindowWidth - Metrics.sidebarWidth
        #expect(column - 2 * AutopilotBarRoom.sideInset > Metrics.autopilotBarPlaceholderWidth * 3)
        #expect(Metrics.autopilotBarWidth <= Metrics.autopilotDockWidth)
    }
}
