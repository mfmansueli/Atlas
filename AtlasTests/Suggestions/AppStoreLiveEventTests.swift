//
//  AppStoreLiveEventTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which In-App Event the App Store preview shows under the screenshots:
/// only one App Review approved whose card shows now (from its publish
/// start until its end), in the storefront's country and language.
@Suite("AppStoreLiveEvent")
struct AppStoreLiveEventTests {
    private static func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text) ?? .distantPast
    }

    private let start = date("2026-11-24T08:00:00Z")
    private let end = date("2026-12-08T08:00:00Z")

    private func event(
        _ id: String = "mood", state: InAppEventState = .published, priority: InAppEventPriority = .normal,
        shows: Date? = nil, start: Date? = nil, end: Date? = nil, territories: [String] = [],
        localizations: [InAppEventLocalization]? = nil
    ) -> InAppEvent {
        InAppEvent(
            id: id, referenceName: "1.4 \(id)", badge: .majorUpdate, state: state, primaryLocale: "en-US", priority: priority,
            schedules: [InAppEventSchedule(
                territories: territories, publishStart: shows ?? start ?? self.start, eventStart: start ?? self.start, eventEnd: end ?? self.end
            )],
            localizations: localizations ?? [
                InAppEventLocalization(id: "\(id)-en", locale: "en-US", name: "Mood Calendar", shortDescription: "See your month in color"),
                InAppEventLocalization(id: "\(id)-de", locale: "de-DE", name: "Stimmungskalender", shortDescription: "Dein Monat in Farbe"),
            ]
        )
    }

    private let middle = date("2026-11-30T12:00:00Z")

    @Test func aPublishedEventWithinItsDatesIsLive() throws {
        let live = try #require(AppStoreLiveEvent.happening(in: [event()], locale: .englishUS, now: middle))
        #expect(live.id == "mood")
        #expect(live.name == "Mood Calendar")
        #expect(live.shortDescription == "See your month in color")
        #expect(live.badgeTitle == "Major Update")
        #expect(live.isHappening)
    }

    /// Alba's Gratitude Week on Nov 25: published, its card up since Nov 22,
    /// starting Nov 26. The App Store shows it already, as upcoming.
    @Test func itsCardShowsFromItsPublishStartAsUpcoming() throws {
        let gratitude = event(
            "gratitude", shows: Self.date("2026-11-22T00:00:00Z"),
            start: Self.date("2026-11-26T00:00:00Z"), end: Self.date("2026-12-02T23:59:00Z")
        )
        #expect(AppStoreLiveEvent.happening(in: [gratitude], locale: .englishUS, now: Self.date("2026-11-21T23:59:59Z")) == nil)
        let upcoming = try #require(AppStoreLiveEvent.happening(in: [gratitude], locale: .englishUS, now: Self.date("2026-11-25T07:45:00Z")))
        #expect(upcoming.id == "gratitude")
        #expect(!upcoming.isHappening)
        let happening = try #require(AppStoreLiveEvent.happening(in: [gratitude], locale: .englishUS, now: Self.date("2026-11-26T00:00:00Z")))
        #expect(happening.isHappening)
        #expect(AppStoreLiveEvent.happening(in: [gratitude], locale: .englishUS, now: Self.date("2026-12-02T23:59:00Z")) == nil)
    }

    @Test func anApprovedEventWhoseCardIsntUpYetDoesntShow() {
        let later = event(
            shows: Self.date("2026-12-04T00:00:00Z"), start: Self.date("2026-12-18T00:00:00Z"), end: Self.date("2026-12-31T23:59:00Z")
        )
        #expect(!AppStoreLiveEvent.isLive(later, now: middle))
        #expect(AppStoreLiveEvent.isLive(later, now: Self.date("2026-12-04T00:00:00Z")))
    }

    @Test func aHappeningEventComesBeforeAnUpcomingOneThenTheSoonest() throws {
        let now = middle
        let happening = event("now", start: Self.date("2026-11-20T00:00:00Z"))
        let soon = event("soon", shows: Self.date("2026-11-28T00:00:00Z"), start: Self.date("2026-12-02T00:00:00Z"), end: Self.date("2026-12-09T00:00:00Z"))
        let later = event("later", shows: Self.date("2026-11-29T00:00:00Z"), start: Self.date("2026-12-05T00:00:00Z"), end: Self.date("2026-12-12T00:00:00Z"))
        #expect(try #require(AppStoreLiveEvent.happening(in: [soon, happening, later], locale: .englishUS, now: now)).id == "now")
        #expect(try #require(AppStoreLiveEvent.happening(in: [later, soon], locale: .englishUS, now: now)).id == "soon")
        let highLater = event(
            "high", priority: .high, shows: Self.date("2026-11-29T00:00:00Z"),
            start: Self.date("2026-12-05T00:00:00Z"), end: Self.date("2026-12-12T00:00:00Z")
        )
        #expect(try #require(AppStoreLiveEvent.happening(in: [happening, highLater], locale: .englishUS, now: now)).id == "high")
    }

    @Test func approvedCountsButNothingBeforeApprovalOrAfterTheEnd() {
        #expect(AppStoreLiveEvent.isLive(event(state: .approved), now: middle))
        for state: InAppEventState in [.draft, .readyForReview, .waitingForReview, .inReview, .rejected, .accepted, .past, .archived] {
            #expect(!AppStoreLiveEvent.isLive(event(state: state), now: middle), "\(state) shouldn't be live")
        }
    }

    @Test func itsLiveFromItsStartUntilItsEnd() {
        let published = event()
        #expect(!AppStoreLiveEvent.isLive(published, now: start.addingTimeInterval(-1)))
        #expect(AppStoreLiveEvent.isLive(published, now: start))
        #expect(AppStoreLiveEvent.isLive(published, now: end.addingTimeInterval(-1)))
        #expect(!AppStoreLiveEvent.isLive(published, now: end))
    }

    /// Dates are moments: an event ending at midnight in California is
    /// still on in the evening there, whatever the zone they were written
    /// in.
    @Test func timeZonesDontMoveTheMoment() {
        let pacific = event(start: Self.date("2026-11-24T00:00:00-08:00"), end: Self.date("2026-12-08T00:00:00-08:00"))
        #expect(AppStoreLiveEvent.isLive(pacific, now: Self.date("2026-12-08T07:30:00Z")))
        #expect(!AppStoreLiveEvent.isLive(pacific, now: Self.date("2026-12-08T08:00:00Z")))
        #expect(!AppStoreLiveEvent.isLive(pacific, now: Self.date("2026-11-24T07:59:59Z")))
        #expect(AppStoreLiveEvent.isLive(pacific, now: Self.date("2026-11-24T17:00:00+09:00")))
    }

    @Test func theDatesReadInTheGivenZone() throws {
        let live = try #require(AppStoreLiveEvent(event(), locale: .englishUS, now: middle))
        let english = Locale(identifier: "en_US")
        let utc = try #require(TimeZone(identifier: "UTC"))
        let hawaii = try #require(TimeZone(identifier: "Pacific/Honolulu"))
        #expect(live.datesText(locale: english, timeZone: utc) == "Nov 24 – Dec 8")
        // Late on Nov 23 and Dec 7 in Hawaii.
        #expect(live.datesText(locale: english, timeZone: hawaii) == "Nov 23 – Dec 7")
    }

    @Test func aScheduleForOtherCountriesDoesntShowHere() {
        let elsewhere = event(territories: ["USA", "CAN"])
        #expect(AppStoreLiveEvent(elsewhere, locale: .englishUS, now: middle) != nil)
        #expect(AppStoreLiveEvent(elsewhere, locale: .german, now: middle) == nil)
        #expect(AppStoreLiveEvent.isLive(elsewhere, now: middle))
    }

    @Test func theStorefrontsLanguageElseThePrimaryOne() throws {
        #expect(try #require(AppStoreLiveEvent(event(), locale: .german, now: middle)).name == "Stimmungskalender")
        #expect(try #require(AppStoreLiveEvent(event(), locale: .japanese, now: middle)).name == "Mood Calendar")
    }

    @Test func anEventWithoutANameDoesntShow() {
        let unnamed = event(localizations: [InAppEventLocalization(id: "x", locale: "en-US")])
        #expect(AppStoreLiveEvent(unnamed, locale: .englishUS, now: middle) == nil)
    }

    @Test func aHighPriorityEventComesFirstThenTheNewest() throws {
        let older = event("older", start: Self.date("2026-11-20T00:00:00Z"))
        let newer = event("newer", start: Self.date("2026-11-26T00:00:00Z"))
        let high = event("high", priority: .high, start: Self.date("2026-11-10T00:00:00Z"))
        #expect(try #require(AppStoreLiveEvent.happening(in: [older, newer], locale: .englishUS, now: middle)).id == "newer")
        #expect(try #require(AppStoreLiveEvent.happening(in: [older, high, newer], locale: .englishUS, now: middle)).id == "high")
    }

    @Test func noLiveEventNoCard() {
        #expect(AppStoreLiveEvent.happening(in: [event(state: .draft), event("over", state: .past)], locale: .englishUS, now: middle) == nil)
        #expect(AppStoreLiveEvent.happening(in: [], locale: .englishUS, now: middle) == nil)
    }

    @Test func theStoreSaysHappeningNowInItsLanguage() {
        #expect(AppStoreWords.words(for: "en-US").happeningNow == "Happening now")
        #expect(AppStoreWords.words(for: "ja").happeningNow == "開催中")
        #expect(AppStoreWords.words(for: "zh-Hant").happeningNow == "正在進行")
        #expect(AppStoreWords.words(for: "xx-YY").happeningNow == "Happening now")
    }

    @Test func theStoreSaysUpcomingInItsLanguage() {
        #expect(AppStoreWords.words(for: "en-US").upcoming == "Upcoming")
        #expect(AppStoreWords.words(for: "pt-BR").upcoming == "Em breve")
        #expect(AppStoreWords.words(for: "zh-Hans").upcoming == "即将推出")
        #expect(AppStoreWords.words(for: "xx-YY").upcoming == "Upcoming")
    }
}
