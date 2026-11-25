//
//  WatchBudget.swift
//  Atlas
//

import Foundation

/// When a Look for Improvements run may start, so it's never a nuisance:
/// only with the switch on and Pro, a known project folder and the helper
/// ready; at most one run per app and three in all per day; none between
/// 22:00 and 08:00; never beside another Claude Code run, within six hours
/// of Claude Code's usage limit, or with App Store Connect's quota low.
/// Pure: the clock and calendar come in.
struct WatchBudget: Sendable {
    static let runsPerAppPerDay = 1
    static let runsPerDay = 3
    /// Quiet from this hour…
    static let quietFrom = 22
    /// …until this one.
    static let quietUntil = 8
    static let usageLimitPause: TimeInterval = 6 * 3600

    var calendar: Calendar = .current

    /// Why a run can't start for `appID` at `now`, nil when it may.
    /// `runStarts` are the runs already started (or planned in this
    /// check), every app's.
    func refusal(for appID: StoreApp.ID, context: WatchContext, runStarts: [(appID: StoreApp.ID, date: Date)], now: Date) -> WatchBudgetRefusal? {
        if !context.isOn { return .turnedOff }
        if !context.isPro { return .notPro }
        if !context.canStartClaudeCode { return .noClaudeCode }
        if !context.appsWithProjectFolder.contains(appID) { return .noProjectFolder }
        if let until = quietUntil(after: now) { return .quietHours(until: until) }
        if context.activeRunCount > 0 { return .anotherRunActive }
        if let hit = context.usageLimitHitAt, now.timeIntervalSince(hit) < Self.usageLimitPause {
            return .usageLimit(until: hit.addingTimeInterval(Self.usageLimitPause))
        }
        if let quota = context.quota, !quota.leavesRoomToReadAhead { return .quotaLow }
        let today = runStarts.filter { calendar.isDate($0.date, inSameDayAs: now) }
        if today.count(where: { $0.appID == appID }) >= Self.runsPerAppPerDay { return .appDailyCap }
        if today.count >= Self.runsPerDay { return .dailyCap }
        return nil
    }

    func isQuietHours(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= Self.quietFrom || hour < Self.quietUntil
    }

    /// The next 08:00 while it's quiet, else nil.
    func quietUntil(after date: Date) -> Date? {
        guard isQuietHours(date) else { return nil }
        return calendar.nextDate(after: date, matching: DateComponents(hour: Self.quietUntil, minute: 0), matchingPolicy: .nextTime)
    }
}
