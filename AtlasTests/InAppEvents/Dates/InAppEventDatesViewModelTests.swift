//
//  InAppEventDatesViewModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A draft's dates on its page, at the view model's clock (Nov 16, 12:00
/// GMT): "Before App Review" lists a card's date that has passed, with the
/// "Shows from" that fixes it; the Event card's row says it has passed,
/// with the time, and Fix…; the footer is never "Ready" while it's open.
/// Editing "Shows from", "Starts" and "Ends" queues one change, with Undo
/// per date. Warnings about App Review's time never block.
@MainActor
@Suite("InAppEventsViewModel · dates")
struct InAppEventDatesViewModelTests {
    typealias Data = InAppEventsTestData

    private let queue = ChangeQueue()
    private let store = InAppEventsStore()
    private let claims = ProjectLinkClaimsCenter()
    private static let gmt = InAppEventDateText(timeZone: .gmt, locale: Locale(identifier: "en_GB"))

    /// Winter, with every language written and its territories.
    private static func event(publish: Double, start: Double, end: Double, territories: [String] = ["USA", "DEU"]) -> InAppEvent {
        var event = Data.winter
        event.localizations.removeLast()
        event.schedules = [InAppEventSchedule(
            territories: territories, publishStart: Data.day(publish), eventStart: Data.day(start), eventEnd: Data.day(end)
        )]
        return event
    }

    /// "7 Days of Gratitude": its card from midnight today, the event
    /// from Nov 20.
    private static let passed = event(publish: -0.5, start: 3.5, end: 10)
    private static let fine = event(publish: 8, start: 15, end: 45)

    private func makeModel(_ event: InAppEvent) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices([event]), store: store, queue: queue)
        model.now = { Data.now }
        model.pageLocales = ["en-US"]
        model.linkClaims = claims
        await model.load()
        model.select(event.id)
        return model
    }

    private func row(_ key: String, in model: InAppEventsViewModel, of event: InAppEvent) throws -> InAppEventSettingsRow {
        try #require(model.settings(of: event, format: Self.gmt).first { $0.key == key })
    }

    @Test func aCardDateThatHasPassedIsOnTheListWithItsFix() async {
        let event = Self.passed
        let model = await makeModel(event)
        let items = model.reviewItems(of: event, format: Self.gmt)
        #expect(items.map(\.id) == ["publishStartPassed"])
        #expect(items[0].state == .missing)
        #expect(items[0].text == """
        The card was set to show from \(Self.gmt.date(Data.day(-0.5))), which has passed. App Store Connect only takes dates in the future.
        """)
        // 2 days from now, for App Review.
        let suggested = Data.day(2)
        #expect(items[0].suggestedDates == [.publishStart: suggested])
        #expect(items[0].detail == "Move “Shows from” later, e.g. to \(Self.gmt.date(suggested)).")
        #expect(model.suggestedPublishStart(of: event, format: Self.gmt) == suggested)
        #expect(model.dateProblems(of: event, format: Self.gmt) == ["\(items[0].text) \(items[0].detail ?? "")"])

        // Never "Ready" while it's open.
        #expect(model.footerText == "To submit: show its card from a time still ahead. Events can go to App Review on their own.")
        #expect(model.footerButton?.isEnabled == false)
        #expect(!model.canSubmitOnItsOwn(event))
        #expect(model.tileNote(of: event).text.contains("Its dates need a fix"))
    }

    @Test func theEventCardsRowSaysTheTimeHasPassed() async throws {
        let event = Self.passed
        let model = await makeModel(event)
        let publish = try row("publish", in: model, of: event)
        #expect(publish.value == "Was set to show from today at 00:00 (your time), which has passed")
        #expect(publish.isProblem)
        #expect(publish.fixField == .publishStart)
        #expect(try !row("dates", in: model, of: event).isProblem)
        // The next morning it names the day.
        model.now = { Data.day(0.9) }
        #expect(try row("publish", in: model, of: event).value == "Was set to show from 16 Nov at 00:00 (your time), which has passed")

        // On its own day, before it shows: the time, not just the day.
        let later = Self.event(publish: 0.25, start: 3.5, end: 10)
        model.now = { Data.now }
        #expect(InAppEventsViewModel.publishText(later, now: Data.now, format: Self.gmt) == "Shows on the App Store from today at 18:00")
        #expect(InAppEventsViewModel.publishText(Self.fine, now: Data.now, format: Self.gmt) == "Shows on the App Store from 24 Nov")
        // Once approved, a date in the past is just when it showed.
        var live = event
        live.state = .published
        #expect(!InAppEventsViewModel.publishText(live, now: Data.now, format: Self.gmt).hasPrefix("Was set"))
    }

    @Test func aStartThatHasPassedIsTheDatesRowsProblem() async throws {
        let event = Self.event(publish: -1, start: -0.25, end: 5)
        let model = await makeModel(event)
        let dates = try row("dates", in: model, of: event)
        #expect(dates.value == "Was set to start today at 06:00 (your time), which has passed")
        #expect(dates.isProblem)
        #expect(dates.fixField == .eventStart)
        #expect(model.reviewItems(of: event).map(\.id) == ["eventStartPassed"])
        #expect(model.suggestedPublishStart(of: event) == nil)
    }

    @Test func showingFromTheSuggestionQueuesNewDates() async throws {
        let event = Self.passed
        let model = await makeModel(event)
        let item = try #require(model.reviewItems(of: event, format: Self.gmt).first)
        model.applySuggestedDates(item.suggestedDates, of: event)

        let change = try #require(model.queuedDates(of: event))
        #expect(!change.isBlocked)
        #expect(change.source == .you)
        #expect(model.dates(of: event)?.publishStart == Data.day(2))
        #expect(model.isDatePending(.publishStart, of: event))
        #expect(!model.isDatePending(.eventStart, of: event))
        #expect(model.dateProblems(of: event).isEmpty)
        #expect(model.suggestedPublishStart(of: event) == nil)
        // It waits in Review & Push, and the row says so instead of the problem.
        let items = model.reviewItems(of: event)
        #expect(items.map(\.state) == [.queued])
        #expect(items[0].stateText == "Waits in Review & Push")
        let publish = try row("publish", in: model, of: event)
        #expect(!publish.isProblem)
        #expect(publish.value.hasSuffix(". New dates wait in Review & Push."))
        #expect(model.footerText == "To submit: push its changes. Events can go to App Review on their own.")
        #expect(!model.tileNote(of: event).text.contains("Its dates need a fix"))

        // Undo on "Shows from": App Store Connect's dates again.
        model.revertDate(.publishStart, of: event)
        #expect(model.queuedDates(of: event) == nil)
        #expect(model.reviewItems(of: event).map(\.state) == [.missing])
    }

    @Test func eachDateIsEditedAndUndoneOnItsOwn() async {
        let event = Self.fine
        let model = await makeModel(event)
        #expect(model.datesEditProblem(of: event) == nil)
        #expect(model.reviewItems(of: event).isEmpty)

        model.setDate(.eventEnd, to: Data.day(10), of: event)
        // Before it starts: on the list, and the change waits blocked.
        #expect(model.reviewItems(of: event).map(\.id) == ["eventEndBeforeStart"])
        #expect(model.queuedDates(of: event)?.isBlocked == true)
        #expect(model.dateProblems(of: event, format: Self.gmt) == ["""
        The event is set to end \(Self.gmt.date(Data.day(10))), which isn’t after it starts (\(Self.gmt.date(Data.day(15)))). \
        Set “Ends” to between 15 minutes and 31 days after “Starts”.
        """])

        model.setDate(.eventEnd, to: Data.day(20), of: event)
        model.setDate(.eventStart, to: Data.day(14), of: event)
        #expect(queue.changes.count == 1)
        #expect(model.queuedDates(of: event)?.isBlocked == false)
        #expect(model.reviewItems(of: event).isEmpty)
        #expect(model.dates(of: event) == InAppEventDates(publishStart: Data.day(8), eventStart: Data.day(14), eventEnd: Data.day(20)))

        model.revertDate(.eventStart, of: event)
        #expect(model.dates(of: event) == InAppEventDates(publishStart: Data.day(8), eventStart: Data.day(15), eventEnd: Data.day(20)))
        #expect(!model.isDatePending(.eventStart, of: event))
        #expect(model.isDatePending(.eventEnd, of: event))
        model.revertDate(.eventEnd, of: event)
        #expect(queue.changes.isEmpty)
    }

    @Test func anAssistantsDatesWaitForAccept() async throws {
        let event = Self.passed
        let model = await makeModel(event)
        var dates = try #require(event.dates)
        dates.publishStart = Data.day(2)
        let builder = InAppEventChangeBuilder(appID: Data.app.id)
        try queue.upsert(#require(builder.datesChange(to: dates, of: event, now: Data.now, source: .assistant(client: "Claude Code"))))
        #expect(model.reviewItems(of: event).map(\.state) == [.suggested])
        #expect(model.footerText.hasPrefix("To submit: accept or show its card from a time still ahead"))
        model.acceptDates(of: event)
        #expect(model.queuedDates(of: event)?.awaitingAcceptance == nil)
        #expect(model.reviewItems(of: event).map(\.state) == [.queued])
    }

    @Test func datesAtlasCantSendStayAsTheyAre() async throws {
        let event = Self.event(publish: -0.5, start: 3.5, end: 10, territories: [])
        let model = await makeModel(event)
        #expect(model.datesEditProblem(of: event)?.hasPrefix("Atlas doesn’t know which countries or regions") == true)
        model.setDate(.publishStart, to: Data.day(2), of: event)
        #expect(queue.changes.isEmpty)
        // Still a problem, without Fix…: it's changed in App Store Connect.
        let publish = try row("publish", in: model, of: event)
        #expect(publish.isProblem)
        #expect(publish.fixField == nil)
        #expect(model.reviewItems(of: event).map(\.id) == ["publishStartPassed"])
    }

    @Test func aCardShowingSoonWarnsWithoutBlocking() async {
        let event = Self.event(publish: 0.5, start: 4, end: 10)
        let model = await makeModel(event)
        let warnings = model.reviewWarnings(of: event, format: Self.gmt)
        #expect(warnings.map(\.id) == ["cardShowsSoon"])
        #expect(warnings[0].text.hasPrefix("The card is set to show in 12 hours. App Review usually takes up to 2 days"))
        #expect(warnings[0].suggestedDates == [.publishStart: Data.day(2)])
        #expect(model.reviewItems(of: event).isEmpty)
        #expect(model.canSubmitOnItsOwn(event))
        #expect(model.footerText == "Ready. Events can go to App Review on their own, without a new version.")
        // Moving it as the warning says clears it.
        model.applySuggestedDates(warnings[0].suggestedDates, of: event)
        #expect(model.reviewWarnings(of: event).isEmpty)
    }

    @Test func theNewEventSheetGetsTheWarningsAtTheClock() async {
        let model = await makeModel(Self.fine)
        var event = NewInAppEvent(now: Data.now)
        #expect(model.warnings(for: event).isEmpty)
        event.eventStart = Data.day(1)
        event.publishStart = Data.day(0.5)
        event.eventEnd = Data.day(5)
        #expect(model.warnings(for: event).count == 1)
        #expect(model.warnings(for: event)[0].hasPrefix("The event starts in 24 hours."))
    }
}
