//
//  InAppEventPushedDatesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Dates pushed a moment ago that a read doesn't show yet: App Store
/// Connect can answer with the old schedule for a short while after the
/// `PATCH`. For two minutes the pushed dates stand, so the event's page
/// asks to fix nothing; one more read after tells which App Store Connect
/// kept.
@MainActor
@Suite("In-App Events · dates just pushed")
struct InAppEventPushedDatesTests {
    typealias Data = InAppEventsTestData

    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    /// Winter, its card from yesterday, with every language and its art.
    private static var old: InAppEvent {
        var event = InAppEventDatesChangeTests.winter
        event.localizations[1].shortDescription = "Kurz"
        event.localizations[1].longDescription = "Lang"
        event.localizations[1].media = Data.media
        event.schedules[0].publishStart = Data.day(-1)
        event.schedules.append(InAppEventSchedule(
            territories: ["JPN"], publishStart: Data.day(-1), eventStart: event.schedules[0].eventStart, eventEnd: event.schedules[0].eventEnd
        ))
        return event
    }

    private static var fixed: InAppEventDates {
        var dates = old.dates ?? InAppEventDates(publishStart: Data.now, eventStart: Data.now, eventEnd: Data.now)
        dates.publishStart = Data.day(3)
        return dates
    }

    private static func showing(_ dates: InAppEventDates) -> InAppEvent {
        var event = old
        for index in event.schedules.indices {
            event.schedules[index].publishStart = dates.publishStart
        }
        return event
    }

    /// A history with Winter's dates pushed `secondsAgo` before `Data.now`.
    private func history(_ dates: InAppEventDates = fixed, secondsAgo: TimeInterval, appID: StoreApp.ID = Data.app.id) throws -> PushHistory {
        let change = try #require(builder.datesChange(to: dates, of: Self.old, now: Data.now, source: .you))
        return PushHistory(records: [PushRecord(
            date: Data.now.addingTimeInterval(-secondsAgo), appID: appID, appName: "Lumen", title: "In-App Events · Dates", pushed: [change]
        )])
    }

    private func settle(_ event: InAppEvent, _ history: PushHistory?, now: Date = Data.now) -> (events: [InAppEvent], readAgainAt: Date?) {
        InAppEventPushedDates(appID: Data.app.id, history: history, now: now).settle([event, Data.update])
    }

    // MARK: - Settling a read

    @Test func aReadBehindThePushGetsThePushedDates() throws {
        let settled = try settle(Self.old, history(secondsAgo: 20))
        let event = try #require(settled.events.first)
        #expect(event.everySchedulesDates == [Self.fixed, Self.fixed])
        #expect(event.schedules.map(\.territories) == [["USA", "DEU"], ["JPN"]])
        #expect(event.reviewNeeds(now: Data.now).isEmpty)
        #expect(settled.events.last == Data.update)
        // Read once more when the two minutes end.
        #expect(settled.readAgainAt == Data.now.addingTimeInterval(100))
    }

    @Test func aReadThatCaughtUpIsLeftAlone() throws {
        let read = Self.showing(Self.fixed)
        let settled = try settle(read, history(secondsAgo: 20))
        #expect(settled.events.first == read)
        #expect(settled.readAgainAt == nil)
    }

    @Test func afterTwoMinutesTheReadIsBelieved() throws {
        let settled = try settle(Self.old, history(secondsAgo: 121))
        #expect(settled.events.first == Self.old)
        #expect(settled.readAgainAt == nil)
        #expect(settle(Self.old, nil).events.first == Self.old)
    }

    @Test func onlyThisAppsPushOfTheseDatesCounts() throws {
        #expect(try settle(Self.old, history(secondsAgo: 20, appID: "other")).events.first == Self.old)
        // A push of other texts of the event isn't a dates push.
        let name = try #require(builder.fieldChange(.name, to: "Winter", in: Self.old.localizations[0], of: Self.old, source: .you))
        let texts = PushHistory(records: [PushRecord(date: Data.now, appID: Data.app.id, appName: "Lumen", title: "Texts", pushed: [name])])
        #expect(settle(Self.old, texts).events.first == Self.old)
    }

    @Test func theNewestPushWins() throws {
        var earlier = Self.fixed
        earlier.publishStart = Data.day(2)
        let change = try #require(builder.datesChange(to: earlier, of: Self.old, now: Data.now, source: .you))
        let latest = try #require(builder.datesChange(to: Self.fixed, of: Self.old, now: Data.now, source: .you))
        let history = PushHistory(records: [
            PushRecord(date: Data.now.addingTimeInterval(-10), appID: Data.app.id, appName: "Lumen", title: "Dates", pushed: [latest]),
            PushRecord(date: Data.now.addingTimeInterval(-60), appID: Data.app.id, appName: "Lumen", title: "Dates", pushed: [change]),
        ])
        #expect(settle(Self.old, history).events.first?.dates == Self.fixed)
    }

    // MARK: - The event's page

    private func makeModel(_ asc: FakeInAppEventsServices, history: PushHistory, clock: Clock) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: asc, store: InAppEventsStore(), queue: ChangeQueue())
        model.now = { clock.now }
        model.linkClaims = ProjectLinkClaimsCenter()
        model.pushHistory = history
        model.readAgain.pause = { clock.now = clock.now.addingTimeInterval($0) }
        await model.load()
        model.select(Self.old.id)
        return model
    }

    /// A clock tests move.
    @MainActor
    final class Clock {
        var now = Data.now
    }

    private func datesToFix(_ model: InAppEventsViewModel) throws -> [InAppEventReviewItem] {
        let event = try #require(model.selectedEvent)
        return model.reviewItems(of: event).filter { $0.need?.dateField != nil }
    }

    @Test func thePageAsksToFixNothingWhileAppStoreConnectCatchesUp() async throws {
        let asc = FakeInAppEventsServices([Self.old, Data.update])
        let clock = Clock()
        let model = try await makeModel(asc, history: history(secondsAgo: 5), clock: clock)
        #expect(try datesToFix(model).isEmpty)
        #expect(model.selectedEvent?.dates == Self.fixed)

        // By the read two minutes on, App Store Connect has them.
        asc.events = [Self.showing(Self.fixed), Data.update]
        await model.readAgain.task?.value
        #expect(clock.now > Data.now.addingTimeInterval(115))
        #expect(model.selectedEvent?.dates == Self.fixed)
        #expect(try datesToFix(model).isEmpty)
    }

    @Test func oldDatesStillReadAfterTwoMinutesAskToBeFixedAgain() async throws {
        let asc = FakeInAppEventsServices([Self.old, Data.update])
        let clock = Clock()
        let model = try await makeModel(asc, history: history(secondsAgo: 5), clock: clock)
        #expect(try datesToFix(model).isEmpty)
        await model.readAgain.task?.value
        #expect(model.selectedEvent?.dates?.publishStart == Data.day(-1))
        #expect(try datesToFix(model).map(\.id) == ["publishStartPassed"])
    }
}
