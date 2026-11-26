//
//  RefreshTextTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Refresh's words (README-DS §15 copy table): the time of the last update
/// is in the tooltip and VoiceOver; the status line speaks only when
/// something is wrong. Times are written as this Mac writes them, so the
/// checks build them with the same formatter.
@Suite("Refresh · words")
struct RefreshTextTests {
    private let now = Date(timeIntervalSince1970: 1_793_000_000)
    private var text: RefreshText {
        RefreshText(now: now, locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC") ?? .current)
    }

    private var twoMinutesAgo: Date { now.addingTimeInterval(-130) }

    @Test func theTooltipHasTheTime() {
        let time = text.time(twoMinutesAgo)
        #expect(text.tooltip(.idle) == "Refresh ⌘R")
        #expect(text.tooltip(.updated(twoMinutesAgo)) == "Refresh ⌘R · Updated 2 minutes ago, at \(time)")
        #expect(text.tooltip(.updated(now)) == "Refresh ⌘R · Updated a moment ago, at \(text.time(now))")
        #expect(text.tooltip(.refreshing(lastUpdated: twoMinutesAgo)) == "Refresh ⌘R · Updating")
        #expect(text.tooltip(.offline(since: twoMinutesAgo)) == "Refresh ⌘R · Offline · from \(time)")
    }

    @Test func voiceOverSaysTheSame() {
        #expect(text.accessibilityLabel(.updated(twoMinutesAgo)) == "Refresh, updated 2 minutes ago")
        #expect(text.accessibilityLabel(.updated(now.addingTimeInterval(-60))) == "Refresh, updated 1 minute ago")
        #expect(text.accessibilityLabel(.refreshing(lastUpdated: nil)) == "Refresh, Updating")
        #expect(text.accessibilityLabel(.idle) == "Refresh")
    }

    @Test func theStatusLineSpeaksOnlyWhenSomethingIsWrong() {
        let copy = AppleErrorCopy(summary: "Apple didn’t answer. Try again in a minute.", details: "HTTP 503")
        #expect(text.statusLine(.updated(twoMinutesAgo)) == nil)
        #expect(text.statusLine(.refreshing(lastUpdated: twoMinutesAgo)) == nil)
        #expect(text.statusLine(.idle) == nil)
        #expect(text.statusLine(.failed(copy, lastUpdated: twoMinutesAgo)) == "Couldn’t update")
        #expect(text.statusLine(.offline(since: twoMinutesAgo)) == "Offline · from \(text.time(twoMinutesAgo))")
        #expect(text.statusLine(.readOnly(role: "Developer", lastUpdated: twoMinutesAgo)) == "View only · updated 2 min ago")
    }

    @Test func theErrorSheetAlwaysSaysNothingIsLost() {
        let copy = AppleErrorCopy(summary: "App Store Connect didn’t answer in time.", details: "URLError -1001")
        #expect(
            text.errorText(copy, lastUpdated: twoMinutesAgo)
                == "App Store Connect didn’t answer in time. What you see is from \(text.time(twoMinutesAgo)), and nothing you changed is lost."
        )
        #expect(text.errorText(copy, lastUpdated: nil) == "App Store Connect didn’t answer in time. Nothing you changed is lost.")
        #expect(!text.errorText(copy, lastUpdated: nil).contains("-1001"), "the code only under Show Details")
    }

    @Test func theAnnouncementComesOnlyWhenItEnds() {
        #expect(text.announcement(.refreshing(lastUpdated: nil)) == nil)
        #expect(text.announcement(.idle) == nil)
        #expect(text.announcement(.updated(now)) == "Updated from App Store Connect.")
        #expect(text.announcement(.failed(AppleErrorCopy(summary: "Try again.", details: nil), lastUpdated: nil)) == "Couldn’t update from App Store Connect.")
    }

    @Test func minutesAreWholeAndNeverNegative() {
        #expect(RefreshText.minutes(from: now.addingTimeInterval(-59), to: now) == 0)
        #expect(RefreshText.minutes(from: now.addingTimeInterval(-61), to: now) == 1)
        #expect(RefreshText.minutes(from: now.addingTimeInterval(30), to: now) == 0)
    }

    @Test func theDotIsAmberOrGreyAndNeverBlue() {
        #expect(RefreshButton.dotColor(for: .failed(AppleErrorCopy(summary: "Try again.", details: nil), lastUpdated: nil)) == Palette.warn)
        #expect(RefreshButton.dotColor(for: .offline(since: now)) == Palette.label2)
        #expect(RefreshButton.dotColor(for: .updated(now)) == nil)
        #expect(RefreshButton.dotColor(for: .readOnly(role: "Developer", lastUpdated: now)) == nil, "View only has its lock in the status line")
        #expect(RefreshStatusLine.symbol(for: .readOnly(role: "Developer", lastUpdated: now)) == "lock.fill")
        let failed = RefreshState.failed(AppleErrorCopy(summary: "Try again.", details: nil), lastUpdated: nil)
        #expect(RefreshStatusLine.symbol(for: failed) == "exclamationmark.triangle.fill")
    }
}
