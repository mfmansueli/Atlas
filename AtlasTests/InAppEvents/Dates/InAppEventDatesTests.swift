//
//  InAppEventDatesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An event's dates against Apple's rules at a clock: Alba 1.2.0 went to
/// App Review on Nov 19 in the afternoon, and App Store Connect refused
/// "7 Days of Gratitude" because its card was set to show from Nov 19 at
/// 00:00 ("Supplied date must be in the future"). Also the warnings about
/// App Review's time (they never block) and the "Shows from" Atlas
/// suggests.
@Suite("In-App Events · dates")
struct InAppEventDatesTests {
    /// Nov 19, 2026 at 15:00 GMT.
    static let now = date("2026-11-19T15:00:00Z")
    static let gmt = InAppEventDateText(timeZone: .gmt, locale: Locale(identifier: "en_GB"))

    static func date(_ text: String) -> Date {
        AppStoreConnectDate.date(text) ?? .distantPast
    }

    /// "7 Days of Gratitude" as Alba submitted it.
    static let alba = InAppEventDates(
        publishStart: date("2026-11-19T00:00:00Z"), eventStart: date("2026-11-23T00:00:00Z"), eventEnd: date("2026-11-29T23:00:00Z")
    )

    static func dates(publish: TimeInterval, start: TimeInterval, end: TimeInterval) -> InAppEventDates {
        InAppEventDates(
            publishStart: now.addingTimeInterval(publish), eventStart: now.addingTimeInterval(start), eventEnd: now.addingTimeInterval(end)
        )
    }

    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86400

    // MARK: - Rules

    @Test func albasCardDateHasPassed() {
        #expect(Self.alba.broken(now: Self.now) == [.publishStartPassed])
        // Before midnight it was fine.
        #expect(Self.alba.broken(now: Self.date("2026-11-18T23:59:00Z")).isEmpty)
        // Without a clock, only what the dates say themselves.
        #expect(Self.alba.broken(now: nil).isEmpty)
        let rule = InAppEventDateRule.publishStartPassed
        #expect(rule.field == .publishStart)
        #expect(rule.text(Self.alba, Self.gmt) == """
        The card was set to show from \(Self.gmt.date(Self.alba.publishStart)), which has passed. App Store Connect only takes dates in the future.
        """)
        let suggestion = Self.date("2026-11-21T15:00:00Z")
        #expect(rule.fix(suggestion: suggestion, Self.gmt) == "Move “Shows from” later, e.g. to \(Self.gmt.date(suggestion)).")
        #expect(InAppEventReviewNeed(rule) == .publishStartPassed)
        #expect(InAppEventReviewNeed.publishStartPassed.footerText == "show its card from a time still ahead")
        #expect(InAppEventReviewNeed.publishStartPassed.dateField == .publishStart)
    }

    /// Days from now: when the card shows, when the event starts and ends.
    @Test(arguments: [
        // Apple's limits, at their edges.
        ([0.5, 1, 1], [InAppEventDateRule.eventEndBeforeStart]),
        ([0.5, 1, 0.5], [.eventEndBeforeStart]),
        ([0.5, 1, 1 + 14.0 / 1440], [.eventTooShort]),
        ([0.5, 1, 1 + 15.0 / 1440], []),
        ([0.5, 1, 32], []),
        ([0.5, 1, 32 + 1.0 / 1440], [.eventTooLong]),
        ([2, 1, 5], [.publishStartAfterEventStart]),
        ([1, 15, 20], []),
        ([1, 15 + 1.0 / 1440, 20], [.publishStartTooEarly]),
        // A card's date that has passed covers a card shown too early.
        ([-1, 14, 20], [.publishStartPassed]),
        ([-1, 1, 5], [.publishStartPassed]),
        // A start that has passed covers the card's date.
        ([-3, -1, 5], [.eventStartPassed]),
        ([-3, 0, 5], [.eventStartPassed]),
        ([-30, -1, 40], [.eventTooLong, .eventStartPassed]),
    ] as [([Double], [InAppEventDateRule])])
    func eachRuleIsCheckedAtTheClock(days: [Double], rules: [InAppEventDateRule]) {
        let dates = Self.dates(publish: days[0] * Self.day, start: days[1] * Self.day, end: days[2] * Self.day)
        #expect(dates.broken(now: Self.now) == rules)
    }

    @Test func eachRuleSaysWhatsWrongInPlainWords() {
        let format = Self.gmt
        var dates = Self.dates(publish: Self.day, start: 2 * Self.day, end: 2 * Self.day + 600)
        #expect(InAppEventDateRule.eventTooShort.text(dates, format) == "The event lasts 10 minutes. Apple’s shortest is 15 minutes.")
        dates.eventEnd = dates.eventStart.addingTimeInterval(40 * Self.day)
        #expect(InAppEventDateRule.eventTooLong.text(dates, format) == "The event lasts 40 days. Apple’s longest is 31 days.")
        dates.publishStart = dates.eventStart.addingTimeInterval(-20 * Self.day)
        let tooEarly = InAppEventDateRule.publishStartTooEarly.text(dates, format)
        #expect(tooEarly == "The card is set to show 20 days before the event starts. Apple allows 14 days at most.")
        dates.eventEnd = dates.eventStart.addingTimeInterval(-Self.hour)
        #expect(InAppEventDateRule.eventEndBeforeStart.text(dates, format) == """
        The event is set to end \(format.date(dates.eventEnd)), which isn’t after it starts (\(format.date(dates.eventStart))).
        """)
        #expect(InAppEventDateRule.eventEndBeforeStart.fix(suggestion: nil, format) == "Set “Ends” to between 15 minutes and 31 days after “Starts”.")
        #expect(InAppEventDateRule.eventStartPassed.fix(suggestion: nil, format) == "Move “Starts” and “Ends” later, and “Shows from” with them.")
        #expect(InAppEventDateRule.eventStartPassed.text(Self.alba, format) == """
        The event was set to start \(format.date(Self.alba.eventStart)), which has passed. App Store Connect only takes dates in the future.
        """)
    }

    // MARK: - App Review's time

    @Test func aCardShowingWithinTwoDaysWarns() {
        let dates = Self.dates(publish: 20 * Self.hour, start: 4 * Self.day, end: 10 * Self.day)
        #expect(dates.broken(now: Self.now).isEmpty)
        #expect(dates.warnings(now: Self.now) == [.cardShowsSoon])
        let warnings = InAppEventReviewWarning.warnings(for: dates, now: Self.now, format: Self.gmt)
        #expect(warnings.map(\.id) == ["cardShowsSoon"])
        #expect(warnings[0].text == """
        The card is set to show in 20 hours. App Review usually takes up to 2 days, and the card only shows once it’s approved, so it may \
        show later than planned.
        """)
        // 2 days from now, on the hour.
        let suggested = Self.date("2026-11-21T15:00:00Z")
        #expect(warnings[0].suggestedDates == [.publishStart: suggested])
        #expect(warnings[0].detail == "To give App Review 2 days, move “Shows from” to \(Self.gmt.date(suggested)).")
    }

    @Test func anEventStartingWithinTwoDaysWarnsMore() throws {
        let dates = Self.dates(publish: 2 * Self.hour, start: 20 * Self.hour, end: 10 * Self.day)
        // Said once: the start's warning includes the card's.
        #expect(dates.warnings(now: Self.now) == [.eventStartsSoon])
        let warning = try #require(InAppEventReviewWarning.warnings(for: dates, now: Self.now, format: Self.gmt).first)
        #expect(warning.text == """
        The event starts in 20 hours. App Review usually takes up to 2 days, so it may start before it’s approved, and its card would \
        miss some of the event.
        """)
        #expect(warning.detail == "To give App Review 2 days, move “Starts” and “Ends” later, or submit it now and expect it to show late.")
        #expect(warning.suggestedDates.isEmpty)
    }

    @Test(arguments: [
        (48.0, false), (47.9, true), (0.5, true), (0, false), (-1, false),
    ] as [(Double, Bool)])
    func theCardsWarningStopsAtTwoDays(hours: Double, warns: Bool) {
        let dates = Self.dates(publish: hours * Self.hour, start: 5 * Self.day, end: 9 * Self.day)
        #expect(dates.warnings(now: Self.now) == (warns ? [.cardShowsSoon] : []))
    }

    @Test func warningsNeverBlock() {
        let dates = Self.dates(publish: Self.hour, start: 2 * Self.hour, end: Self.day)
        #expect(dates.broken(now: Self.now).isEmpty)
        var event = InAppEventsTestData.winter
        event.localizations.removeLast()
        event.schedules = [InAppEventSchedule(
            territories: ["USA"], publishStart: dates.publishStart, eventStart: dates.eventStart, eventEnd: dates.eventEnd
        )]
        #expect(event.canSubmit(now: Self.now))
        #expect(InAppEventReviewWarning.warnings(for: event, queued: nil, now: Self.now).map(\.id) == ["eventStartsSoon"])
        // A live event has nothing to warn about.
        event.state = .published
        #expect(InAppEventReviewWarning.warnings(for: event, queued: nil, now: Self.now).isEmpty)
    }

    // MARK: - The "Shows from" Atlas suggests

    @Test func theSuggestionGivesAppReviewTwoDays() {
        let calendar = Self.gmt.calendar
        #expect(Self.alba.suggestedPublishStart(now: Self.now, calendar: calendar) == Self.date("2026-11-21T15:00:00Z"))
        // On the next hour.
        #expect(Self.alba.suggestedPublishStart(now: Self.date("2026-11-19T15:20:00Z"), calendar: calendar) == Self.date("2026-11-21T16:00:00Z"))
    }

    @Test func theSuggestionKeepsTheCardWithinFourteenDaysOfTheStart() {
        let far = InAppEventDates(
            publishStart: Self.date("2026-11-10T00:00:00Z"), eventStart: Self.date("2026-12-20T00:00:00Z"), eventEnd: Self.date("2026-12-27T00:00:00Z")
        )
        let suggested = far.suggestedPublishStart(now: Self.now, calendar: Self.gmt.calendar)
        #expect(suggested == Self.date("2026-12-06T00:00:00Z"))
        var fixed = far
        fixed.publishStart = suggested ?? far.publishStart
        #expect(fixed.broken(now: Self.now).isEmpty)
    }

    @Test func whenTwoDaysDontFitTheSuggestionIsTheEarliestTimeAhead() {
        let calendar = Self.gmt.calendar
        // Starts in 20 hours: the card from the next hour after 30 minutes.
        let soon = Self.dates(publish: -Self.hour, start: 20 * Self.hour, end: 5 * Self.day)
        #expect(soon.suggestedPublishStart(now: Self.now, calendar: calendar) == Self.date("2026-11-19T16:00:00Z"))
        // Starts in 10 minutes: no time is left; the event has to move.
        let tooSoon = Self.dates(publish: -Self.hour, start: 600, end: 5 * Self.day)
        #expect(tooSoon.suggestedPublishStart(now: Self.now, calendar: calendar) == nil)
        #expect(InAppEventDateRule.publishStartPassed.fix(suggestion: nil, Self.gmt) == "Move “Shows from” later, and the event with it if it starts too soon.")
    }

    // MARK: - An event's needs

    @Test func anEventWhoseCardDateHasPassedCantGoToAppReview() {
        var event = InAppEventsTestData.winter
        event.localizations.removeLast()
        event.schedules = [InAppEventSchedule(
            territories: ["USA"], publishStart: Self.alba.publishStart, eventStart: Self.alba.eventStart, eventEnd: Self.alba.eventEnd
        )]
        #expect(event.reviewNeeds(now: Self.now) == [.publishStartPassed])
        #expect(event.missing(now: Self.now) == ["show its card from a time still ahead"])
        #expect(!event.canSubmit(now: Self.now))
        #expect(event.canSubmit(now: Self.date("2026-11-18T12:00:00Z")))
        // Without dates: one need, on "Starts".
        event.schedules = []
        #expect(event.reviewNeeds(now: Self.now) == [.dates])
        #expect(InAppEventReviewNeed.dates.dateField == .eventStart)
    }

    // MARK: - New Event

    @Test func theNewEventSheetWarnsAboutAppReviewsTime() {
        var event = NewInAppEvent(now: Self.now)
        event.referenceName = "Spring Reset 2027"
        event.texts["en-US"] = [.name: "Spring Reset", .shortDescription: "A fresh start", .longDescription: "Seven days of small habits."]
        #expect(event.warnings(now: Self.now).isEmpty)
        event.publishStart = Self.now.addingTimeInterval(20 * Self.hour)
        event.eventStart = Self.now.addingTimeInterval(3 * Self.day)
        event.eventEnd = Self.now.addingTimeInterval(9 * Self.day)
        #expect(event.warnings(now: Self.now, format: Self.gmt) == [InAppEventDateWarning.cardShowsSoon.text(event.dates, now: Self.now, Self.gmt)])
        #expect(event.problems(now: Self.now).isEmpty)
        // A card's date that has passed is a problem, not a warning.
        event.publishStart = Self.now.addingTimeInterval(-Self.hour)
        #expect(event.warnings(now: Self.now).isEmpty)
        #expect(event.problems(now: Self.now) == ["The card has to start showing in the future. Show it from later."])
    }

    // MARK: - In the person's words

    @Test func datesSayTheDayAndTimeInThePersonsZone() {
        let format = Self.gmt
        let midnight = Self.date("2026-11-19T00:00:00Z")
        #expect(format.dayAndTime(midnight, now: Self.now) == "today at 00:00")
        #expect(format.dayAndTime(midnight, now: Self.date("2026-11-20T09:00:00Z")) == "19 Nov at 00:00")
        #expect(format.timeUntil(Self.now.addingTimeInterval(20 * Self.hour), from: Self.now) == "in 20 hours")
        #expect(format.timeUntil(Self.now.addingTimeInterval(Self.hour + 59), from: Self.now) == "in 1 hour")
        #expect(format.timeUntil(Self.now.addingTimeInterval(59 * 60), from: Self.now) == "in 59 minutes")
        #expect(format.timeUntil(Self.now.addingTimeInterval(60), from: Self.now) == "in 1 minute")
        #expect(format.zoneName.hasSuffix("(GMT)"))
        let brasilia = InAppEventDateText(timeZone: TimeZone(identifier: "America/Sao_Paulo") ?? .gmt, locale: Locale(identifier: "en_US"))
        #expect(brasilia.zoneName.hasPrefix("Brasilia"))
        #expect(brasilia.zoneName.hasSuffix(" (GMT-3)"))
        let india = InAppEventDateText(timeZone: TimeZone(identifier: "Asia/Kolkata") ?? .gmt, locale: Locale(identifier: "en_US"))
        #expect(india.zoneName.hasSuffix("(GMT+5:30)"))
        // In São Paulo, Alba's midnight GMT was the evening before.
        #expect(brasilia.dayAndTime(midnight, now: Self.now).hasPrefix("Nov 18 at"))
    }
}
