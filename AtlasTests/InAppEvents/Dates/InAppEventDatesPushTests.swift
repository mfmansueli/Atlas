//
//  InAppEventDatesPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// New dates pushed: the queued Dates change leaves Review & Push whole
/// (an assistant's dates beside it with it), so nothing still reads
/// "Waits in Review & Push" or "Suggested", and once the events are read
/// again the "Before App Review" list has no date to fix. An assistant's
/// dates beside the person's keep the change from going until one is
/// picked.
@MainActor
@Suite("In-App Events · dates after a push")
struct InAppEventDatesPushTests {
    typealias Data = InAppEventsTestData

    private let queue = ChangeQueue()
    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    /// Winter, its card from yesterday, read with its territories.
    private static var winter: InAppEvent {
        var event = InAppEventDatesChangeTests.winter
        event.schedules[0].publishStart = Data.day(-1)
        return event
    }

    private static var later: InAppEventDates {
        var dates = winter.dates ?? InAppEventDates(publishStart: Data.now, eventStart: Data.now, eventEnd: Data.now)
        dates.publishStart = Data.day(3)
        return dates
    }

    private static func pushed(_ event: InAppEvent, _ dates: InAppEventDates) -> InAppEvent {
        var event = event
        for index in event.schedules.indices {
            event.schedules[index].publishStart = dates.publishStart
            event.schedules[index].eventStart = dates.eventStart
            event.schedules[index].eventEnd = dates.eventEnd
        }
        return event
    }

    private func push(_ event: InAppEvent) async throws -> FakePushTransport {
        let publish = try #require(event.schedules.first?.publishStart)
        let json = #"{"data":{"attributes":{"territorySchedules":[{"publishStart":"\#(AppStoreConnectDate.text(publish))"}]}}}"#
        let transport = FakePushTransport(remote: ["/v1/appEvents/\(event.id)?fields[appEvents]=territorySchedules": Foundation.Data(json.utf8)])
        let push = PushController(queue: queue, history: PushHistory(), transport: transport)
        push.push(queue.changes(for: Data.app.id))
        await push.waitUntilFinished()
        return transport
    }

    private func items(_ event: InAppEvent) -> [InAppEventReviewItem] {
        InAppEventReviewItem.items(
            for: event, changes: queue.changes(for: Data.app.id, section: .inAppEvents), builder: builder, claim: .noDeepLink,
            appName: Data.app.name, now: Data.now
        )
    }

    @Test func thePushedDatesLeaveNothingWaiting() async throws {
        let event = Self.winter
        let change = try #require(builder.datesChange(to: Self.later, of: event, now: Data.now, source: .you))
        queue.upsert(change)
        #expect(items(event).first { $0.id == "publishStartPassed" }?.state == .queued)

        let transport = try await push(event)
        #expect(transport.sent.map(\.method) == [.patch])
        #expect(queue.changes(for: Data.app.id).isEmpty)
        #expect(builder.queuedDates(for: event.id, in: queue.changes(for: Data.app.id)) == nil)
        // Before the events are read again, the list still says what App
        // Store Connect had; read again, no date is left to fix.
        #expect(items(event).first { $0.id == "publishStartPassed" }?.state == .missing)
        let read = Self.pushed(event, Self.later)
        #expect(!items(read).contains { $0.need?.dateField != nil })
        #expect(!items(read).contains { $0.state == .queued || $0.state == .suggested })
    }

    @Test func anAssistantsDatesBesideThePersonsKeepItFromGoing() async throws {
        let event = Self.winter
        var change = try #require(builder.datesChange(to: Self.later, of: event, now: Data.now, source: .you))
        var theirs = Self.later
        theirs.publishStart = Data.day(4)
        change.alternative = builder.datesAlternative(to: theirs, of: event, now: Data.now, source: .assistant(client: "Claude Code"))
        queue.upsert(change)
        #expect(items(event).first { $0.id == "publishStartPassed" }?.state == .suggested)

        let transport = try await push(event)
        #expect(transport.sent.isEmpty)
        #expect(builder.queuedDates(for: event.id, in: queue.changes(for: Data.app.id)) != nil)
    }
}
