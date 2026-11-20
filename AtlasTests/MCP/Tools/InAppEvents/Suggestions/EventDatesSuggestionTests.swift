//
//  EventDatesSuggestionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An assistant's dates for an event whose dates the person already
/// queued never overwrite theirs: they wait beside them as a suggestion,
/// on the event's page and in Review & Push, until the person accepts them
/// (they replace theirs) or dismisses them (theirs stay). Alba, Nov 19:
/// the person queued Nov 21 18:00 / Nov 23 / Nov 29 23:59; Claude moved
/// the event to Nov 26 – Dec 2 23:59, keeping the card's date.
@MainActor
@Suite("In-App Events MCP · dates beside the person's")
struct EventDatesSuggestionTests {
    typealias Data = InAppEventsTestData

    private let store = InAppEventsStore()
    private let changes = ChangeQueue()
    private let claims = ProjectLinkClaimsCenter()
    private let builder = InAppEventChangeBuilder(appID: InAppEventsTestData.app.id)

    private static func date(_ text: String) -> Date {
        AppStoreConnectDate.date(text) ?? .distantPast
    }

    /// Alba's clock: Nov 19, 12:00 GMT.
    private static let now = date("2026-11-19T12:00:00Z")

    /// Winter as App Store Connect has it: its card from Nov 18, which
    /// has passed, the event Nov 20 – Nov 27.
    private static let event: InAppEvent = {
        var event = Data.winter
        event.localizations.removeLast()
        event.schedules = [InAppEventSchedule(
            territories: ["USA", "DEU"], publishStart: date("2026-11-18T00:00:00Z"), eventStart: date("2026-11-20T00:00:00Z"),
            eventEnd: date("2026-11-27T00:00:00Z")
        )]
        return event
    }()

    /// The dates the person queued themselves.
    private static let persons = InAppEventDates(
        publishStart: date("2026-11-21T18:00:00Z"), eventStart: date("2026-11-23T00:00:00Z"), eventEnd: date("2026-11-29T23:59:00Z")
    )

    private func queuePersons(_ dates: InAppEventDates = Self.persons) throws {
        let change = try #require(builder.datesChange(to: dates, of: Self.event, now: Self.now, source: .you))
        changes.upsert(change)
    }

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue], client: String = "Claude Code") async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices([Self.event])
        let context = MCPToolContext(workspace: workspace, clientName: client, allowedProposals: Set(MCPProposalKind.allCases))
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func propose(_ dates: [String: JSONValue], reason: String = "The streak now starts on a Thursday.", client: String = "Claude Code")
        async throws -> MCPToolOutcome
    {
        var arguments: [String: JSONValue] = ["appId": "Lumen Journal", "eventId": "winter", "reason": .string(reason)]
        arguments.merge(dates) { $1 }
        return try await call(ProposeEventDetailsTool(store: store, now: { Self.now }), arguments, client: client)
    }

    private static func reasons(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private var queued: PendingChange? {
        builder.queuedDates(for: Self.event.id, in: changes.changes(for: Data.app.id, section: .inAppEvents))
    }

    // MARK: - propose_event_details

    @Test func albasDatesWaitBesideThePersonsOwn() async throws {
        try queuePersons()
        let outcome = try await propose(["eventStart": "2026-11-26T00:00:00Z", "eventEnd": "2026-12-02T23:59:00Z"])
        #expect(outcome.result["status"] == "suggested")
        #expect(outcome.result["queued"]?.arrayValue?.isEmpty == true)
        // What the person queued is kept, and said so.
        #expect(outcome.result["personsDates"]?["publishStart"] == "2026-11-21T18:00:00Z")
        #expect(outcome.result["personsDates"]?["eventStart"] == "2026-11-23T00:00:00Z")
        #expect(outcome.result["personsDates"]?["by"] == "You")
        #expect(outcome.result["note"]?.stringValue?.contains("those are kept") == true)
        #expect(outcome.result["note"]?.stringValue?.contains("accepts yours") == true)
        // The suggestion keeps the person's card date (it wasn't sent).
        let suggested = try #require(outcome.result["suggested"]?.arrayValue?.first)
        #expect(suggested["publishStart"] == "2026-11-21T18:00:00Z")
        #expect(suggested["eventStart"] == "2026-11-26T00:00:00Z")
        #expect(suggested["eventEnd"] == "2026-12-02T23:59:00Z")
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.proposed)

        let change = try #require(queued)
        #expect(change.source == .you)
        #expect(InAppEventChangeBuilder.datesValue(in: change) == Self.persons)
        let alternative = try #require(change.alternative)
        #expect(alternative.source == .assistant(client: "Claude Code"))
        #expect(alternative.note == "The streak now starts on a Thursday.")
        #expect(alternative.blockedReason == nil)
        #expect(change.needsDecision)
        #expect(changes.changes(for: Data.app.id, section: .inAppEvents).count == 1)
    }

    @Test func omittedDatesComeFromThePersonsChange() async throws {
        try queuePersons()
        let outcome = try await propose(["eventStart": "2026-11-24T00:00:00Z"])
        let suggested = try #require(outcome.result["suggested"]?.arrayValue?.first)
        #expect(suggested["publishStart"] == "2026-11-21T18:00:00Z")
        #expect(suggested["eventEnd"] == "2026-11-29T23:59:00Z")
    }

    @Test func omittedDatesComeFromAppStoreConnectWithoutTheirs() async throws {
        let outcome = try await propose(["publishStart": "2026-11-19T18:00:00Z"])
        #expect(outcome.result["status"] == "queued")
        let dates = try #require(queued.flatMap(InAppEventChangeBuilder.datesValue))
        #expect(dates.eventStart == Self.date("2026-11-20T00:00:00Z"))
        #expect(queued?.source == .assistant(client: "Claude Code"))
        #expect(queued?.alternative == nil)
    }

    @Test func theSameDatesAsThePersonsChangeNothing() async throws {
        try queuePersons()
        let outcome = try await propose(["eventStart": "2026-11-23T00:00:00Z"])
        #expect(outcome.result["status"] == "unchanged")
        #expect(outcome.result["unchangedNote"] == "The person already queued these dates; nothing else was queued for them.")
        #expect(queued?.alternative == nil)
        #expect(queued?.source == .you)
    }

    @Test func datesThatBreakARuleAreRefusedAndTheirsStay() async throws {
        try queuePersons()
        // Ends before it starts.
        let backwards = try await propose(["eventStart": "2026-11-26T00:00:00Z", "eventEnd": "2026-11-25T00:00:00Z"])
        #expect(backwards.result["status"] == "refused")
        #expect(Self.reasons(backwards).contains { $0.hasPrefix("eventEnd:") })
        // The card more than 14 days before the start.
        let early = try await propose(["eventStart": "2026-12-10T00:00:00Z", "eventEnd": "2026-12-12T00:00:00Z"])
        #expect(early.result["status"] == "refused")
        #expect(Self.reasons(early).contains { $0.hasPrefix("publishStart:") })
        // In the past.
        let past = try await propose(["publishStart": "2026-11-19T06:00:00Z"])
        #expect(past.result["status"] == "refused")
        // Longer than Apple takes.
        let long = try await propose(["eventEnd": "2027-01-30T00:00:00Z"])
        #expect(long.result["status"] == "refused")

        #expect(queued?.alternative == nil)
        #expect(queued.flatMap(InAppEventChangeBuilder.datesValue) == Self.persons)
    }

    @Test func sendingDatesAgainReplacesTheSuggestion() async throws {
        try queuePersons()
        _ = try await propose(["eventStart": "2026-11-26T00:00:00Z", "eventEnd": "2026-12-02T23:59:00Z"])
        _ = try await propose(["eventStart": "2026-11-25T00:00:00Z", "eventEnd": "2026-12-01T23:59:00Z"], reason: "One day earlier.")
        let alternative = try #require(queued?.alternative)
        #expect(alternative.note == "One day earlier.")
        let dates = try #require(InAppEventChangeBuilder.datesValue(in: alternative.requests))
        #expect(dates.eventStart == Self.date("2026-11-25T00:00:00Z"))
        // Sending the person's own dates takes it back.
        _ = try await propose(["eventStart": "2026-11-23T00:00:00Z", "eventEnd": "2026-11-29T23:59:00Z"])
        #expect(queued?.alternative == nil)
    }

    // MARK: - get_in_app_events

    @Test func getInAppEventsShowsTheSuggestionBesideTheirs() async throws {
        try queuePersons()
        _ = try await propose(["eventStart": "2026-11-26T00:00:00Z", "eventEnd": "2026-12-02T23:59:00Z"])
        let tool = GetInAppEventsTool(store: store, directory: EventArtworkTestFiles.directory(), linkClaims: claims, now: { Self.now })
        let read = try await call(tool, ["appId": "Lumen Journal", "eventId": "winter", "include": ["review"]])
        let event = try #require(read.result["events"]?.arrayValue?.first)
        let dates = try #require(event["queuedDates"])
        #expect(dates["eventStart"] == "2026-11-23T00:00:00Z")
        #expect(dates["by"] == "You")
        #expect(dates["suggestion"]?["eventStart"] == "2026-11-26T00:00:00Z")
        #expect(dates["suggestion"]?["by"] == "Claude Code")
        #expect(dates["suggestion"]?["reason"] == "The streak now starts on a Thursday.")
    }

    // MARK: - The event's page

    private func makeModel() async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices([Self.event]), store: store, queue: changes)
        model.now = { Self.now }
        model.pageLocales = ["en-US"]
        model.linkClaims = claims
        await model.load()
        model.select(Self.event.id)
        return model
    }

    @Test func acceptReplacesThePersonsDates() async throws {
        try queuePersons()
        _ = try await propose(["eventStart": "2026-11-26T00:00:00Z", "eventEnd": "2026-12-02T23:59:00Z"])
        let model = await makeModel()
        let suggested = try #require(model.suggestedDates(of: Self.event))
        #expect(suggested.dates.eventStart == Self.date("2026-11-26T00:00:00Z"))
        // "Before App Review": the card's date is filled, but waits for a pick.
        #expect(model.reviewItems(of: Self.event).first { $0.id == "publishStartPassed" }?.state == .suggested)

        model.acceptSuggestedDates(of: Self.event)
        #expect(model.suggestedDates(of: Self.event) == nil)
        let change = try #require(queued)
        #expect(change.alternative == nil)
        #expect(InAppEventChangeBuilder.datesValue(in: change)?.eventEnd == Self.date("2026-12-02T23:59:00Z"))
        #expect(change.groupNote == "The streak now starts on a Thursday.")
        #expect(model.reviewItems(of: Self.event).first { $0.id == "publishStartPassed" }?.state == .queued)
    }

    @Test func dismissKeepsThePersonsDates() async throws {
        try queuePersons()
        _ = try await propose(["eventStart": "2026-11-26T00:00:00Z", "eventEnd": "2026-12-02T23:59:00Z"])
        let model = await makeModel()
        model.dismissSuggestedDates(of: Self.event)
        #expect(model.suggestedDates(of: Self.event) == nil)
        #expect(queued?.alternative == nil)
        #expect(queued.flatMap(InAppEventChangeBuilder.datesValue) == Self.persons)
        #expect(queued?.source == .you)
    }
}
