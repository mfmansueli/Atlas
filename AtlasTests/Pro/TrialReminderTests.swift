//
//  TrialReminderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The reminder the paywall promises: two days before a free trial
/// becomes a paid plan, and only then.
@MainActor
@Suite("TrialReminder")
struct TrialReminderTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let end = FakeProStore.trialEnd
    private static let started = end.addingTimeInterval(-7 * 86400)

    @Test func comesTwoDaysBeforeTheTrialEnds() throws {
        let status = ProStatus.subscribed(plan: .yearly, until: Self.end, isTrial: true)
        let reminder = try #require(TrialReminder(status: status, now: Self.started, calendar: Self.calendar))
        #expect(reminder.trialEnd == Self.end)
        #expect(reminder.fireDate == Self.end.addingTimeInterval(-2 * 86400))
        #expect(reminder.title == "Your Atlas Pro trial ends in 2 days")
        #expect(reminder.body.hasPrefix("On "))
        #expect(reminder.body.hasSuffix("cancel in your App Store subscriptions before then."))
    }

    @Test func nothingWithoutATrial() {
        #expect(TrialReminder(status: .free, now: Self.started) == nil)
        #expect(TrialReminder(status: .lifetime, now: Self.started) == nil)
        #expect(TrialReminder(status: .subscribed(plan: .monthly, until: Self.end, isTrial: false), now: Self.started) == nil)
        #expect(TrialReminder(status: .subscribed(plan: .yearly, until: nil, isTrial: true), now: Self.started) == nil)
    }

    @Test func nothingOnceTheMomentHasPassed() {
        let status = ProStatus.subscribed(plan: .yearly, until: Self.end, isTrial: true)
        let lastDay = Self.end.addingTimeInterval(-86400)
        #expect(TrialReminder(status: status, now: lastDay, calendar: Self.calendar) == nil)
    }

    @Test func theSchedulerFollowsWhatThePersonOwns() {
        let scheduler = TrialReminderScheduler(center: nil, now: { Self.started })
        scheduler.update(for: .subscribed(plan: .yearly, until: Self.end, isTrial: true))
        #expect(scheduler.pending?.trialEnd == Self.end)
        // The trial turned into the paid plan: nothing left to remind.
        scheduler.update(for: .subscribed(plan: .yearly, until: Self.end.addingTimeInterval(365 * 86400), isTrial: false))
        #expect(scheduler.pending == nil)
    }

    @Test func buyingTheYearlyTrialSetsTheReminder() async {
        let scheduler = TrialReminderScheduler(center: nil, now: { Self.started })
        let entitlements = Entitlements(store: FakeProStore(), trialReminder: scheduler)
        _ = await entitlements.purchase(.yearly)
        #expect(scheduler.pending != nil)
        _ = await entitlements.restore()
        #expect(scheduler.pending == nil, "Restore found nothing: Free, so no reminder")
    }
}
