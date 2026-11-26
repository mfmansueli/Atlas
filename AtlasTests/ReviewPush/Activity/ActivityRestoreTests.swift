//
//  ActivityRestoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Restore Previous Values only queues: the old values wait on To Push,
/// the toast says nothing was pushed, and Review & Push switches to To
/// Push.
@MainActor
@Suite("Activity · Restore Previous Values")
struct ActivityRestoreTests {
    @Test func theOldValuesWaitInReviewAndPush() throws {
        let queue = ChangeQueue(changes: [])
        let record = DebugReviewData.activityRecords[0]
        let toast = try #require(ActivityRestore.restore(record, into: queue))
        #expect(queue.changes.count == record.pushed.count)
        #expect(toast.text == "The previous values for 24 changes are in Review & Push. Nothing was pushed.")
        let restored = try #require(queue.changes.first { $0.id == record.pushed[0].id })
        #expect(restored.newValue == record.pushed[0].oldValue, "the value from before the push")
    }

    @Test func nothingToRestoreShowsNoToast() {
        let queue = ChangeQueue(changes: [])
        var record = DebugReviewData.activityRecords[0]
        record.pushed = []
        #expect(ActivityRestore.restore(record, into: queue) == nil)
        #expect(queue.changes.isEmpty)
    }

    @Test func restoringSwitchesToToPushAndClearsTheHighlight() {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.openActivity(highlighting: UUID())
        navigator.showToPush()
        #expect(navigator.reviewTab == .toPush)
        #expect(navigator.highlightedPushID == nil)
        #expect(navigator.isReviewPresented)
    }
}
