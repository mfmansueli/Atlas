//
//  WatchBudgetTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// When a run may start: switch, Pro, Claude Code and folder first, then
/// quiet hours, another run, the usage limit, the quota and the day's caps.
@Suite("Look for Improvements · budget")
struct WatchBudgetTests {
    private typealias Data = WatchTestData
    private let budget = WatchBudget(calendar: Data.calendar)
    private let noon = Data.date(hour: 12)

    private func refusal(
        _ context: WatchContext = Data.context, app: StoreApp.ID = Data.lumen, runs: [(appID: StoreApp.ID, date: Date)] = [], at date: Date? = nil
    ) -> WatchBudgetRefusal? {
        budget.refusal(for: app, context: context, runStarts: runs, now: date ?? noon)
    }

    @Test func aRunMayStartWithEverythingReady() {
        #expect(refusal() == nil)
    }

    @Test func theSwitchProClaudeCodeAndTheFolderComeFirst() {
        var context = Data.context
        context.isOn = false
        #expect(refusal(context, at: Data.date(hour: 23)) == .turnedOff)
        context = Data.context
        context.isPro = false
        #expect(refusal(context) == .notPro)
        context = Data.context
        context.canStartClaudeCode = false
        #expect(refusal(context) == .noClaudeCode)
        #expect(refusal(app: "unknown") == .noProjectFolder)
    }

    @Test func quietFrom22To8() {
        #expect(refusal(at: Data.date(hour: 21, minute: 59)) == nil)
        #expect(refusal(at: Data.date(hour: 22)) == .quietHours(until: Data.date(hour: 8, days: 1)))
        #expect(refusal(at: Data.date(hour: 7, minute: 59)) == .quietHours(until: Data.date(hour: 8)))
        #expect(refusal(at: Data.date(hour: 8)) == nil)
        #expect(budget.quietUntil(after: noon) == nil)
    }

    @Test func neverBesideAnotherRun() {
        var context = Data.context
        context.activeRunCount = 1
        #expect(refusal(context) == .anotherRunActive)
    }

    @Test func sixHoursAfterTheUsageLimit() {
        var context = Data.context
        context.usageLimitHitAt = noon.addingTimeInterval(-5 * 3600)
        #expect(refusal(context) == .usageLimit(until: noon.addingTimeInterval(3600)))
        context.usageLimitHitAt = noon.addingTimeInterval(-6 * 3600)
        #expect(refusal(context) == nil)
    }

    @Test func notWhenTheQuotaLeavesNoRoomToReadAhead() {
        var context = Data.context
        context.quota = AppStoreConnectRateLimit(limit: 3600, remaining: 100)
        #expect(refusal(context) == .quotaLow)
        context.quota = AppStoreConnectRateLimit(limit: 3600, remaining: 3000)
        #expect(refusal(context) == nil)
    }

    @Test func oneRunPerAppAndThreeInAllPerDay() {
        let morning = Data.date(hour: 9)
        #expect(refusal(runs: [(Data.lumen, morning)]) == .appDailyCap)
        #expect(refusal(runs: [(Data.lumen, Data.date(hour: 9, days: -1))]) == nil)
        let three: [(appID: StoreApp.ID, date: Date)] = [("a", morning), ("b", morning), ("c", morning)]
        #expect(refusal(runs: three) == .dailyCap)
        #expect(refusal(runs: Array(three.prefix(2))) == nil)
    }
}
