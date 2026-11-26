//
//  ActivityTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Activity's words (README-DS §15): each push's line, the tab's VoiceOver
/// summary, the toast after Restore and a failure's reason, never Apple's
/// raw text.
@Suite("Activity · words")
struct ActivityTextTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    /// 25 Nov 2026, 15:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_795_618_800)
    private var text: ActivityText { ActivityText(now: now, calendar: Self.calendar, locale: Locale(identifier: "en_US")) }

    private func record(hoursAgo: Double, failures: Int = 0, pushed: Int = 3) -> PushRecord {
        let changes = Array(DebugReviewData.activityRecords[0].pushed.prefix(pushed))
        let failed = Array(DebugReviewData.activityRecords[0].pushed.suffix(failures))
        return PushRecord(
            date: now.addingTimeInterval(-hoursAgo * 3600),
            appID: "1",
            appName: "Lumen Journal",
            title: "Store Page · 3 texts",
            pushed: changes,
            failures: Dictionary(uniqueKeysWithValues: failed.map { ($0.id, "ENTITY_ERROR.ATTRIBUTE.INVALID — Too long.") }),
            failedChanges: failed
        )
    }

    @Test func aPushSaysTheAppWhenAndHowMany() {
        let line = text.details(of: record(hoursAgo: 1))
        #expect(line.hasPrefix("Lumen Journal · Today, "))
        #expect(line.hasSuffix(" · 3 changes"))
        #expect(text.when(now.addingTimeInterval(-20)) == "A moment ago")
        #expect(text.when(now.addingTimeInterval(-24 * 3600)).hasPrefix("Yesterday, "))
        #expect(ActivityText.changes(1) == "1 change")
    }

    @Test func voiceOverSumsUpToday() {
        #expect(text.summary(of: []) == "Activity, nothing pushed yet")
        let today = [record(hoursAgo: 1), record(hoursAgo: 2, failures: 1), record(hoursAgo: 3)]
        #expect(text.summary(of: today) == "Activity, 3 pushes today, 1 failed")
        #expect(text.summary(of: [record(hoursAgo: 1)]) == "Activity, 1 push today")
        #expect(text.summary(of: [record(hoursAgo: 48), record(hoursAgo: 72)]) == "Activity, 2 pushes, none today")
    }

    @Test func theToastSaysNothingWasPushed() {
        #expect(ActivityText.restored(23) == "The previous values for 23 changes are in Review & Push. Nothing was pushed.")
        #expect(ActivityText.restored(1) == "The previous value for 1 change is in Review & Push. Nothing was pushed.")
    }

    @Test func theStateIsGreenOrAmber() {
        #expect(ActivityText.allSucceeded == "All succeeded")
        #expect(ActivityText.failed(1) == "1 failed")
    }

    @Test func applesRefusalStaysInDetails() throws {
        let record = DebugReviewData.activityRecords[1]
        let change = try #require(record.failedChanges.first)
        let copy = ActivityText.failure(of: change, in: record)
        #expect(copy.summary == "\(change.title): Apple refused the change. See Details.")
        #expect(!copy.summary.contains("ENTITY_ERROR"))
        #expect(copy.details?.contains("ENTITY_ERROR.RELATIONSHIP.INVALID") == true)
    }

    @Test func atlassOwnReasonIsShown() throws {
        var record = DebugReviewData.activityRecords[1]
        let change = try #require(record.failedChanges.first)
        record.failures[change.id] = AppleErrorCopy(summary: "Apple didn’t answer. Try again in a minute.", details: "HTTP 503").text
        let copy = ActivityText.failure(of: change, in: record)
        #expect(copy.summary == "\(change.title): Apple didn’t answer. Try again in a minute.")
        #expect(copy.details == "HTTP 503")
        #expect(ActivityText.isApplesText("HTTP 409"))
        #expect(!ActivityText.isApplesText("Apple didn’t answer."))
    }
}
