//
//  EventDatesToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A draft's dates over MCP, at the tools' clock (Nov 16, 12:00 GMT):
/// `propose_event_details` moves them with the same rules as the event's
/// page (refused with the fix, or with why Atlas can't send them), and
/// `get_in_app_events` lists a date App Store Connect would refuse in
/// `missingForReview`, with a `suggested` card's date, and App Review's
/// time in `reviewWarnings`. Alba 1.2.0: "7 Days of Gratitude" was
/// refused because its card's date had passed.
@MainActor
@Suite("In-App Events MCP · dates")
struct EventDatesToolsTests {
    typealias Data = InAppEventsTestData

    private let store = InAppEventsStore()
    private let changes = ChangeQueue()
    private let claims = ProjectLinkClaimsCenter()

    /// Winter with every language written and its territories.
    private static func event(publish: Double, start: Double, end: Double, territories: [String] = ["USA", "DEU"]) -> InAppEvent {
        var event = Data.winter
        event.localizations.removeLast()
        event.schedules = [InAppEventSchedule(
            territories: territories, publishStart: Data.day(publish), eventStart: Data.day(start), eventEnd: Data.day(end)
        )]
        return event
    }

    /// Its card from midnight today (Nov 16), the event from Nov 20.
    private static let passed = event(publish: -0.5, start: 3.5, end: 10)

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue], events: [InAppEvent] = [passed]) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: Set(MCPProposalKind.allCases))
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func propose(_ dates: [String: JSONValue], events: [InAppEvent] = [passed]) async throws -> MCPToolOutcome {
        var arguments: [String: JSONValue] = ["appId": "Lumen Journal", "eventId": "winter", "reason": "Its card’s date has passed."]
        arguments.merge(dates) { $1 }
        return try await call(ProposeEventDetailsTool(store: store, now: { Data.now }), arguments, events: events)
    }

    private func read(_ events: [InAppEvent] = [passed]) async throws -> (result: JSONValue, event: JSONValue) {
        let tool = GetInAppEventsTool(store: store, directory: EventArtworkTestFiles.directory(), linkClaims: claims, now: { Data.now })
        let result = try await call(tool, ["appId": "Lumen Journal"], events: events).result
        let event = try #require(result["events"]?.arrayValue?.first)
        return (result, event)
    }

    private static func reasons(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    // MARK: - get_in_app_events

    @Test func aCardDateThatHasPassedIsMissingForReviewWithAWorkingOne() async throws {
        let (result, event) = try await read()
        #expect(event["readyForReview"] == false)
        #expect(event["datesEditable"] == true)
        let missing = try #require(event["missingForReview"]?.arrayValue)
        #expect(missing.count == 1)
        #expect(missing[0]["item"] == "publishStartPassed")
        #expect(missing[0]["state"] == "missing")
        #expect(missing[0]["text"]?.stringValue?.hasPrefix("The card was set to show from") == true)
        #expect(missing[0]["text"]?.stringValue?.hasSuffix("which has passed. App Store Connect only takes dates in the future.") == true)
        #expect(missing[0]["fix"]?.stringValue?.hasPrefix("Move “Shows from” later, e.g. to") == true)
        // Two days from now, for App Review.
        #expect(missing[0]["suggested"]?["publishStart"] == "2026-11-18T12:00:00Z")
        #expect(event["reviewWarnings"]?.arrayValue?.isEmpty == true)
        #expect(result["limits"]?["shortestEventMinutes"] == 15)
        #expect(result["limits"]?["appReviewUsuallyTakesHours"] == 48)
    }

    @Test func aCardShowingSoonIsAWarningNotANeed() async throws {
        let (_, event) = try await read([Self.event(publish: 0.5, start: 4, end: 10)])
        #expect(event["readyForReview"] == true)
        let warnings = try #require(event["reviewWarnings"]?.arrayValue)
        #expect(warnings.count == 1)
        #expect(warnings[0]["item"] == "cardShowsSoon")
        #expect(warnings[0]["text"]?.stringValue?.hasPrefix("The card is set to show in 12 hours.") == true)
        #expect(warnings[0]["suggested"]?["publishStart"] == "2026-11-18T12:00:00Z")
    }

    @Test func datesAtlasCantSendSayWhy() async throws {
        let (_, event) = try await read([Self.event(publish: -0.5, start: 3.5, end: 10, territories: [])])
        #expect(event["datesEditable"] == false)
        #expect(event["datesNotEditable"]?.stringValue?.hasPrefix("Atlas doesn’t know where") == true)
        #expect(event["missingForReview"]?.arrayValue?.first?["item"] == "publishStartPassed")
    }

    // MARK: - propose_event_details

    @Test func aDraftsCardDateMovesAsOneChangeWaitingForAcceptance() async throws {
        let outcome = try await propose(["publishStart": "2026-11-18T12:00:00Z"])
        #expect(outcome.result["status"] == "queued")
        let queued = try #require(outcome.result["queued"]?.arrayValue?.first)
        #expect(queued["detail"] == "territorySchedules")
        #expect(queued["publishStart"] == "2026-11-18T12:00:00Z")
        // The others stay as they are.
        #expect(queued["eventStart"] == .string(AppStoreConnectDate.text(Data.day(3.5))))
        #expect(queued["eventEnd"] == .string(AppStoreConnectDate.text(Data.day(10))))
        // Exactly 2 days ahead: nothing to warn about.
        #expect(outcome.result["warning"] == nil)

        let change = try #require(changes.changes.first)
        #expect(changes.changes.count == 1)
        #expect(queued["changeId"] == .string(change.id))
        #expect(change.id == InAppEventChangeBuilder(appID: Data.app.id).datesChangeID(eventID: "winter"))
        #expect(change.awaitingAcceptance != nil)
        #expect(change.groupNote == "Its card’s date has passed.")
        #expect(change.requests.first?.path == "/v1/appEvents/winter")

        let (_, event) = try await read()
        #expect(event["queuedDates"]?["publishStart"] == "2026-11-18T12:00:00Z")
        #expect(event["queuedDates"]?["waitingForAcceptance"] == true)
        #expect(event["missingForReview"]?.arrayValue?.first?["state"] == "suggested")
    }

    @Test func aDateInAnotherTimeZoneIsTheSameInstant() async throws {
        let outcome = try await propose(["publishStart": "2026-11-18T09:00:00-03:00"])
        #expect(outcome.result["queued"]?.arrayValue?.first?["publishStart"] == "2026-11-18T12:00:00Z")
    }

    @Test func allThreeDatesMoveTogether() async throws {
        let outcome = try await propose([
            "publishStart": "2026-11-27T00:00:00Z", "eventStart": "2026-12-04T00:00:00Z", "eventEnd": "2026-12-10T23:00:00Z",
        ])
        #expect(outcome.result["status"] == "queued")
        let dates = try InAppEventChangeBuilder.datesValue(in: #require(changes.changes.first))
        #expect(dates?.eventStart == AppStoreConnectDate.date("2026-12-04T00:00:00Z"))
        #expect(dates?.eventEnd == AppStoreConnectDate.date("2026-12-10T23:00:00Z"))
    }

    @Test(arguments: [
        (["publishStart": "2026-11-16T06:00:00Z"], "publishStart: The card was set to show from"),
        (["eventEnd": "2026-11-19T00:00:00Z"], "eventEnd: The event is set to end"),
        (["eventStart": "2026-11-16T06:00:00Z"], "eventStart: The event was set to start"),
        (["eventEnd": "2027-01-30T00:00:00Z"], "eventEnd: The event lasts 71 days. Apple’s longest is 31 days."),
        (
            ["publishStart": "2026-11-17T00:00:00Z", "eventStart": "2026-12-10T00:00:00Z", "eventEnd": "2026-12-15T00:00:00Z"],
            "publishStart: The card is set to show 23 days before the event starts."
        ),
    ] as [([String: String], String)])
    func datesThatBreakARuleAreRefusedWithTheFix(dates: [String: String], reason: String) async throws {
        let outcome = try await propose(dates.mapValues(JSONValue.string))
        #expect(outcome.result["status"] == "refused")
        #expect(Self.reasons(outcome).contains { $0.hasPrefix(reason) }, "\(Self.reasons(outcome))")
        #expect(changes.changes.isEmpty)
    }

    @Test func aRefusedCardDateSaysWhichOneWorks() async throws {
        let outcome = try await propose(["publishStart": "2026-11-16T06:00:00Z"])
        let reason = try #require(Self.reasons(outcome).first)
        #expect(reason.hasSuffix("(publishStart 2026-11-18T12:00:00Z)"))
    }

    @Test func aDateWithoutATimeZoneIsAnArgumentError() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await propose(["publishStart": "2026-11-18"])
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await propose(["eventEnd": "next Friday"])
        }
        #expect(changes.changes.isEmpty)
    }

    @Test func datesAtlasCantSendAreRefusedWithWhy() async throws {
        let outcome = try await propose(
            ["publishStart": "2026-11-18T12:00:00Z"], events: [Self.event(publish: -0.5, start: 3.5, end: 10, territories: [])]
        )
        #expect(outcome.result["status"] == "refused")
        #expect(Self.reasons(outcome).first?.hasPrefix("dates: Atlas doesn’t know where") == true)
        #expect(changes.changes.isEmpty)
    }

    @Test func aCardShowingSoonIsQueuedWithAWarning() async throws {
        let outcome = try await propose(["publishStart": "2026-11-17T00:00:00Z"], events: [Self.event(publish: 2, start: 4, end: 10)])
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["warning"]?.stringValue?.hasPrefix("The card is set to show in 12 hours.") == true)
        #expect(outcome.result["reviewWarnings"]?.arrayValue?.first?["item"] == "cardShowsSoon")
        #expect(changes.changes.first?.isBlocked == true)
        #expect(changes.changes.first?.blockedReason == nil)
    }

    @Test func theSameDatesAreUnchanged() async throws {
        let outcome = try await propose(
            ["publishStart": .string(AppStoreConnectDate.text(Data.day(8)))], events: [Self.event(publish: 8, start: 15, end: 45)]
        )
        #expect(outcome.result["status"] == "unchanged")
        #expect(outcome.result["unchanged"] == ["territorySchedules"])
        #expect(changes.changes.isEmpty)
    }

    @Test func theToolsSayWhatTheyTake() {
        let details = ProposeEventDetailsTool().definition
        #expect(details.description.contains("publishStart"))
        #expect(details.description.contains("Supplied date must be in the future"))
        #expect(GetInAppEventsTool().definition.description.contains("reviewWarnings"))
        #expect(MCPEndpoint.instructions.contains("move dates that have passed"))
    }
}
