//
//  BackgroundCheckScheduleTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("BackgroundCheckSchedule")
struct BackgroundCheckScheduleTests {
    private let now = Date(timeIntervalSinceReferenceDate: 815_000_000)

    @Test func checksAtOnceWhenNeverChecked() {
        #expect(BackgroundCheckSchedule.nextCheck(after: nil, interval: .everyHour, isPaused: false, now: now) == now)
        #expect(BackgroundCheckSchedule.isDue(after: nil, interval: .everyHour, isPaused: false, now: now))
    }

    @Test func nextCheckIsOneIntervalAfterTheLast() {
        let last = now.addingTimeInterval(-20 * 60)
        let next = BackgroundCheckSchedule.nextCheck(after: last, interval: .everyHour, isPaused: false, now: now)
        #expect(next == last.addingTimeInterval(3600))
        #expect(!BackgroundCheckSchedule.isDue(after: last, interval: .everyHour, isPaused: false, now: now))
        #expect(BackgroundCheckSchedule.isDue(after: last, interval: .every15Minutes, isPaused: false, now: now))
    }

    @Test func anOverdueCheckIsDueNow() {
        let last = now.addingTimeInterval(-7 * 3600)
        #expect(BackgroundCheckSchedule.nextCheck(after: last, interval: .every6Hours, isPaused: false, now: now) == now)
    }

    @Test func pausedOrOnlyWhenAskedNeverChecksOnItsOwn() {
        #expect(BackgroundCheckSchedule.nextCheck(after: nil, interval: .everyHour, isPaused: true, now: now) == nil)
        #expect(BackgroundCheckSchedule.nextCheck(after: nil, interval: .onlyWhenAsked, isPaused: false, now: now) == nil)
        #expect(!BackgroundCheckSchedule.isDue(after: nil, interval: .onlyWhenAsked, isPaused: false, now: now))
    }

    @Test func statusLineSaysWhenItLastAndNextChecks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let last = now.addingTimeInterval(-60)
        let line = BackgroundCheckSchedule.statusLine(last: last, interval: .everyHour, isPaused: false, now: now, calendar: calendar)
        #expect(line.hasPrefix("Last checked "))
        #expect(line.contains(" · next check "))
    }

    @Test func statusLineWhenPausedOrOnlyWhenAsked() {
        let paused = BackgroundCheckSchedule.statusLine(last: nil, interval: .everyHour, isPaused: true, now: now)
        #expect(paused == "Not checked yet · paused")
        let manual = BackgroundCheckSchedule.statusLine(last: nil, interval: .onlyWhenAsked, isPaused: false, now: now)
        #expect(manual == "Not checked yet · checks only when you ask")
        let soon = BackgroundCheckSchedule.statusLine(last: nil, interval: .everyHour, isPaused: false, now: now)
        #expect(soon == "Not checked yet · checking soon")
    }

    @Test func intervalsInSeconds() {
        #expect(CheckInterval.every15Minutes.seconds == 900)
        #expect(CheckInterval.everyHour.seconds == 3600)
        #expect(CheckInterval.every6Hours.seconds == 21600)
        #expect(CheckInterval.onlyWhenAsked.seconds == nil)
        #expect(CheckInterval.allCases.map(\.title) == ["Every 15 minutes", "Every hour", "Every 6 hours", "Only when I ask"])
    }
}
