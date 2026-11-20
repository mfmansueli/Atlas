//
//  InAppEventDatesChangeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A draft's new dates as one Review & Push change: `PATCH
/// /v1/appEvents/{id}` with `territorySchedules` alone, as App Store
/// Connect API 4.6's `AppEventUpdateRequest` has it (`data` with `type`,
/// `id` and `attributes.territorySchedules`, each schedule with
/// `territories`, `publishStart`, `eventStart` and `eventEnd`), every
/// schedule keeping its territories. Restorable, checked for conflicts by
/// instant, and refused when Atlas doesn't know the territories.
@MainActor
@Suite("In-App Events · dates change")
struct InAppEventDatesChangeTests {
    typealias Data = InAppEventsTestData

    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    /// Winter, read with its territories.
    static var winter: InAppEvent {
        var event = Data.winter
        event.schedules[0].territories = ["USA", "DEU"]
        return event
    }

    static var moved: InAppEventDates {
        var dates = winter.dates ?? InAppEventDates(publishStart: Data.now, eventStart: Data.now, eventEnd: Data.now)
        dates.publishStart = Data.day(10)
        return dates
    }

    private static func json(_ request: PushRequest?) throws -> [String: Any] {
        let body = try #require(request?.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private static func schedules(_ document: [String: Any]) throws -> [[String: Any]] {
        let data = try #require(document["data"] as? [String: Any])
        let attributes = try #require(data["attributes"] as? [String: Any])
        return try #require(attributes["territorySchedules"] as? [[String: Any]])
    }

    @Test func theDatesGoAsOnePatchInTheShapeAppleDocuments() throws {
        let change = try #require(builder.datesChange(to: Self.moved, of: Self.winter, now: Data.now, source: .you))
        #expect(change.id == "inAppEvents.\(Data.app.id).winter.details.territorySchedules")
        #expect(change.id == builder.datesChangeID(eventID: "winter"))
        #expect(change.section == .inAppEvents)
        #expect(change.groupID == "winter")
        #expect(change.title == "Dates")
        #expect(!change.isBlocked)
        let request = try #require(change.requests.first)
        #expect(change.requests.count == 1)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/appEvents/winter")

        let document = try Self.json(request)
        #expect(Set(document.keys) == ["data"])
        let data = try #require(document["data"] as? [String: Any])
        #expect(Set(data.keys) == ["type", "id", "attributes"])
        #expect(data["type"] as? String == "appEvents")
        #expect(data["id"] as? String == "winter")
        let attributes = try #require(data["attributes"] as? [String: Any])
        #expect(Set(attributes.keys) == ["territorySchedules"])
        let schedules = try Self.schedules(document)
        #expect(schedules.count == 1)
        #expect(Set(schedules[0].keys) == ["territories", "publishStart", "eventStart", "eventEnd"])
        #expect(schedules[0]["territories"] as? [String] == ["USA", "DEU"])
        #expect(schedules[0]["publishStart"] as? String == AppStoreConnectDate.text(Data.day(10)))
        #expect(schedules[0]["eventStart"] as? String == AppStoreConnectDate.text(Data.day(15)))
        #expect(schedules[0]["eventEnd"] as? String == AppStoreConnectDate.text(Data.day(45)))
        // ISO 8601 with a time zone, as the spec's date-time.
        #expect((schedules[0]["publishStart"] as? String)?.hasSuffix("Z") == true)
        #expect(InAppEventChangeBuilder.datesValue(in: change) == Self.moved)
    }

    @Test func everyScheduleKeepsItsOwnTerritories() throws {
        var event = Self.winter
        let schedule = event.schedules[0]
        event.schedules = [
            schedule,
            InAppEventSchedule(territories: ["JPN"], publishStart: schedule.publishStart, eventStart: schedule.eventStart, eventEnd: schedule.eventEnd),
        ]
        let change = try #require(builder.datesChange(to: Self.moved, of: event, now: Data.now, source: .you))
        let schedules = try Self.schedules(Self.json(change.requests.first))
        #expect(schedules.map { $0["territories"] as? [String] } == [["USA", "DEU"], ["JPN"]])
        #expect(schedules.allSatisfy { $0["publishStart"] as? String == AppStoreConnectDate.text(Data.day(10)) })
    }

    @Test func undoingPutsAppStoreConnectsDatesBack() throws {
        let format = InAppEventDateText(timeZone: .gmt, locale: Locale(identifier: "en_GB"))
        let change = try #require(builder.datesChange(to: Self.moved, of: Self.winter, now: Data.now, source: .you, format: format))
        let restore = try Self.schedules(Self.json(change.restoreRequests.first))
        #expect(restore[0]["publishStart"] as? String == AppStoreConnectDate.text(Data.day(8)))
        #expect(restore[0]["territories"] as? [String] == ["USA", "DEU"])
        #expect(change.oldValue == """
        Shows from \(format.date(Data.day(8)))
        Starts \(format.date(Data.day(15)))
        Ends \(format.date(Data.day(45)))
        """)
        #expect(change.newValue.hasPrefix("Shows from \(format.date(Data.day(10)))\n"))
        // The same dates as App Store Connect's: nothing to queue.
        let live = try #require(Self.winter.dates)
        #expect(builder.datesChange(to: live, of: Self.winter, now: Data.now, source: .you) == nil)
    }

    @Test func aConflictIsTheCardsDateChangingNotItsFormat() throws {
        let change = try #require(builder.datesChange(to: Self.moved, of: Self.winter, now: Data.now, source: .you))
        let check = try #require(change.conflictCheck)
        #expect(check.path == "/v1/appEvents/winter?fields[appEvents]=territorySchedules")
        #expect(check.format == .date)
        let same = Foundation.Data(#"""
        {"data":{"type":"appEvents","id":"winter","attributes":{"territorySchedules":[
          {"territories":["USA","DEU"],"publishStart":"2026-11-24T12:00:00.000Z","eventStart":"2026-12-01T12:00:00Z","eventEnd":"2026-12-31T12:00:00Z"}
        ]}}}
        """#.utf8)
        #expect(check.expected == AppStoreConnectDate.text(Data.day(8)))
        #expect(check.value(in: same) == "2026-11-24T12:00:00.000Z")
        #expect(!check.differs(from: check.value(in: same)))
        #expect(check.differs(from: "2026-11-25T12:00:00Z"))
        // A text check still compares the text.
        var text = check
        text.format = .text
        #expect(text.differs(from: "2026-11-24T12:00:00.000Z"))
    }

    @Test func datesThatBreakARuleWaitBlockedWithWhy() throws {
        var passed = Self.moved
        passed.publishStart = Data.day(-1)
        let change = try #require(builder.datesChange(to: passed, of: Self.winter, now: Data.now, source: .you))
        #expect(change.isBlocked)
        #expect(change.blockedReason?.hasPrefix("The card was set to show from") == true)
    }

    @Test func anAssistantsDatesWaitForAcceptance() throws {
        let change = try #require(builder.datesChange(
            to: Self.moved, of: Self.winter, now: Data.now, source: .assistant(client: "Claude Code"), reason: "Gives App Review two days."
        ))
        #expect(change.awaitingAcceptance == "Look at it, then accept it here or on the event’s page.")
        #expect(change.groupNote == "Gives App Review two days.")
        #expect(builder.queuedDates(for: "winter", in: [change])?.id == change.id)
        #expect(builder.dates(of: Self.winter, in: [change]) == Self.moved)
        #expect(builder.dates(of: Self.winter, in: []) == Self.winter.dates)
    }

    @Test func atlasNeverGuessesTerritories() {
        // Read without its territories: changing the dates would change those too.
        let unknown = Data.winter
        #expect(InAppEventChangeBuilder.datesEditProblem(of: unknown) == """
        Atlas doesn’t know which countries or regions “Winter Reflection 2026” shows in, so it can’t send new dates without changing those \
        too. Change its dates in App Store Connect.
        """)
        #expect(builder.datesChange(to: Self.moved, of: unknown, now: Data.now, source: .you) == nil)

        var split = Self.winter
        split.schedules.append(InAppEventSchedule(
            territories: ["JPN"], publishStart: Data.day(9), eventStart: Data.day(15), eventEnd: Data.day(45)
        ))
        #expect(InAppEventChangeBuilder.datesEditProblem(of: split)?.hasSuffix("change these in App Store Connect.") == true)

        var undated = Self.winter
        undated.schedules[0].publishStart = nil
        #expect(
            InAppEventChangeBuilder.datesEditProblem(of: undated) == "“Winter Reflection 2026” has no dates in App Store Connect yet. Set them there first."
        )

        var live = Self.winter
        live.state = .published
        #expect(InAppEventChangeBuilder.datesEditProblem(of: live)?.contains("only a draft, an event ready for review or a rejected one can change") == true)
        #expect(InAppEventChangeBuilder.datesEditProblem(of: Self.winter) == nil)
    }
}
