//
//  ProposeInAppEventToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_in_app_event`: an assistant's new In-App Event queued in Review
/// & Push as the New Event sheet's change, or refused with reasons that say
/// how to fix it, and the queued event in `get_in_app_events`. "Now" is
/// Nov 16, 2026; nothing reaches App Store Connect.
@MainActor
@Suite("propose_in_app_event")
struct ProposeInAppEventToolTests {
    typealias Data = InAppEventsTestData

    private let changes = ChangeQueue()
    private let store = InAppEventsStore()
    static let alba = StoreApp(id: "6825428345", name: "Alba: Daily Motivation", bundleID: "com.example.alba", primaryLocale: "en-US")

    private func call(
        _ tool: some MCPTool,
        _ arguments: [String: JSONValue],
        events: [InAppEvent] = Data.events,
        client: String = "Claude Code",
        allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(apps: MCPTestFixtures.apps + [Self.alba], changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        let context = MCPToolContext(workspace: workspace, clientName: client, allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func propose(_ arguments: [String: JSONValue], events: [InAppEvent] = Data.events, client: String = "Claude Code") async throws -> MCPToolOutcome {
        try await call(ProposeInAppEventTool(now: { Data.now }), arguments, events: events, client: client)
    }

    /// Alba's January challenge, as the person described it.
    private func newYear(_ overrides: [String: JSONValue] = [:]) -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [
            "appId": "6825428345",
            "referenceName": "New Year Challenge 2027",
            "badge": "CHALLENGE",
            "purchaseRequirement": "NO_COST_ASSOCIATED",
            "publishStart": "2026-12-18T00:00:00Z",
            "eventStart": "2027-01-01T00:00:00Z",
            "eventEnd": "2027-01-31T23:59:00Z",
            "texts": ["en-US": [
                "name": "New Year, New Mindset",
                "shortDescription": "Start 2027 with a phrase every single morning",
                "longDescription": "Pick the topics that move you, open Alba every morning in January and build a 30-day streak.",
            ]],
            "reason": "January is when people start a habit; Alba's streaks fit a 30-day challenge.",
            "evidence": ["Alba/Streaks/StreakView.swift:12 — the 30-day streak"],
        ]
        arguments.merge(overrides) { $1 }
        return arguments
    }

    private static func attributes(_ change: PendingChange) throws -> [String: Any] {
        let body = try #require(change.requests.first?.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        return try #require((object["data"] as? [String: Any])?["attributes"] as? [String: Any])
    }

    private static func reasons(_ outcome: MCPToolOutcome) -> [String] {
        outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    // MARK: - Queued

    @Test func albasNewYearChallengeWaitsInReviewAndPush() async throws {
        let outcome = try await propose(newYear(), events: [])

        #expect(outcome.result["status"] == "queued")
        let change = try #require(changes.changes.first)
        #expect(changes.changes.count == 1)
        #expect(outcome.result["changeId"] == .string(change.id))
        #expect(change.id.hasPrefix("inAppEvents.6825428345.new-event."))
        #expect(change.title == "Create “New Year Challenge 2027”")
        #expect(ReviewCreation.group([change]).first?.title == "Create “New Year Challenge 2027”")
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.blockedReason == nil)

        let attributes = try Self.attributes(change)
        #expect(attributes["referenceName"] as? String == "New Year Challenge 2027")
        #expect(attributes["badge"] as? String == "CHALLENGE")
        #expect(attributes["purchaseRequirement"] as? String == "NO_COST_ASSOCIATED")
        #expect(attributes["purpose"] as? String == "APPROPRIATE_FOR_ALL_USERS")
        #expect(attributes["priority"] as? String == "NORMAL")
        #expect(attributes["primaryLocale"] as? String == "en-US")
        #expect(attributes["deepLink"] == nil)
        let schedule = try #require((attributes["territorySchedules"] as? [[String: Any]])?.first)
        #expect(schedule["territories"] as? [String] == ["{everyTerritory}"])
        #expect(schedule["publishStart"] as? String == "2026-12-18T00:00:00Z")
        #expect(schedule["eventStart"] as? String == "2027-01-01T00:00:00Z")
        #expect(schedule["eventEnd"] as? String == "2027-01-31T23:59:00Z")

        #expect(change.requests.map(\.path) == ["/v1/appEvents", "/v1/appEventLocalizations"])
        let english = try #require(InAppEventWriteDocument.decode(change.requests[1].body))
        #expect(english.data.attributes["locale"] == "en-US")
        #expect(english.data.relationships?["appEvent"]?.data.id == "{createdID}")
        #expect(english.texts == [
            .name: "New Year, New Mindset",
            .shortDescription: "Start 2027 with a phrase every single morning",
            .longDescription: "Pick the topics that move you, open Alba every morning in January and build a 30-day streak.",
        ])

        let fields = Dictionary(uniqueKeysWithValues: (change.creation?.fields ?? []).map { ($0.id, $0.newValue) })
        #expect(fields["event.reason"] == "January is when people start a habit; Alba's streaks fit a 30-day challenge.")
        #expect(fields["event.evidence"] == "Alba/Streaks/StreakView.swift:12 — the 30-day streak")
        #expect(outcome.logLines == [.init(target: "Alba: Daily Motivation · New Year Challenge 2027", outcome: .proposed)])
    }

    @Test func theResultSaysTheArtworkPushAndReviewAreStillThePersons() async throws {
        let outcome = try await propose(newYear(), events: [])
        let note = try #require(outcome.result["note"]?.stringValue)
        #expect(note.contains("event card and details page artwork still have to be added"))
        #expect(note.contains("the person pushes the event and submits it for review"))
        // Without a deep link it's created, but App Review won't take it.
        let stillNeeded = outcome.result["stillNeeded"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(stillNeeded.count == 3)
        #expect(stillNeeded.first?.hasPrefix("A deep link: App Store Connect won't take the event to App Review without one.") == true)
        #expect(outcome.result["showsIn"]?.stringValue?.contains("Create “New Year Challenge 2027”") == true)
    }

    @Test func theNewFieldsAndChosenTerritoriesAreWritten() async throws {
        _ = try await propose(newYear([
            "badge": "Special Event", "purpose": "bring_back_lapsed_users", "priority": "HIGH", "purchaseRequirement": "IN_APP_PURCHASE",
            "deepLink": "alba://challenge/new-year", "territories": ["USA", "br", "BRA"],
        ]))
        let attributes = try Self.attributes(#require(changes.changes.first))
        #expect(attributes["badge"] as? String == "SPECIAL_EVENT")
        #expect(attributes["purpose"] as? String == "BRING_BACK_LAPSED_USERS")
        #expect(attributes["priority"] as? String == "HIGH")
        #expect(attributes["purchaseRequirement"] as? String == "IN_APP_PURCHASE")
        #expect(attributes["deepLink"] as? String == "alba://challenge/new-year")
        #expect((attributes["territorySchedules"] as? [[String: Any]])?.first?["territories"] as? [String] == ["USA", "BRA"])
    }

    @Test func proposingYourOwnEventAgainReplacesIt() async throws {
        _ = try await propose(newYear())
        let first = try #require(changes.changes.first)
        let again = try await propose(newYear(["eventEnd": "2027-01-15T00:00:00Z"]))
        #expect(again.result["status"] == "queued")
        #expect(again.result["replacedYourEarlierProposal"] == true)
        #expect(changes.changes.count == 1)
        #expect(changes.changes.first?.id == first.id)
        let schedule = try (Self.attributes(#require(changes.changes.first))["territorySchedules"] as? [[String: Any]])?.first
        #expect(schedule?["eventEnd"] as? String == "2027-01-15T00:00:00Z")
    }

    @Test func theQueuedEventShowsInGetInAppEvents() async throws {
        _ = try await propose(newYear(["deepLink": "https://alba.app/new-year"]), events: [])
        let read = try await call(GetInAppEventsTool(store: store, now: { Data.now }), ["appId": "Alba: Daily Motivation"], events: [])
        #expect(read.result["events"] == [])
        let id = try #require(changes.changes.first).id
        let queued = try #require(read.result["queued"]?.arrayValue?.first)
        #expect(queued["changeId"] == .string(id))
        #expect(queued["title"] == "Create “New Year Challenge 2027”")
        #expect(queued["referenceName"] == "New Year Challenge 2027")
        #expect(queued["badge"] == "CHALLENGE")
        #expect(queued["purchaseRequirement"] == "NO_COST_ASSOCIATED")
        #expect(queued["deepLink"] == "https://alba.app/new-year")
        #expect(queued["primaryLanguage"] == "en-US")
        #expect(queued["showsFrom"] == "2026-12-18T00:00:00Z")
        #expect(queued["starts"] == "2027-01-01T00:00:00Z")
        #expect(queued["ends"] == "2027-01-31T23:59:00Z")
        #expect(queued["territories"] == "all")
        #expect(queued["texts"]?["en-US"]?["name"] == "New Year, New Mindset")
        #expect(queued["by"] == "Claude Code")
        #expect(read.result["limits"]?["referenceName"] == .int(64))
    }

    /// App Review usually takes up to 2 days and the event shows only once
    /// it's approved: a card set to show sooner comes back with a
    /// `warning`, not a refusal.
    @Test func aCardShowingWithinTwoDaysComesBackWithAWarning() async throws {
        let soon = try await propose(newYear([
            "publishStart": "2026-11-17T00:00:00Z", "eventStart": "2026-11-24T00:00:00Z", "eventEnd": "2026-11-30T00:00:00Z",
        ]), events: [])
        #expect(soon.result["status"] == "queued")
        #expect(soon.result["warning"]?.stringValue?.hasPrefix("The card is set to show in 12 hours. App Review usually takes up to 2 days") == true)
        #expect(changes.changes.first?.blockedReason == nil)

        let calm = try await propose(newYear(["referenceName": "New Year Challenge 2028"]), events: [])
        #expect(calm.result["status"] == "queued")
        #expect(calm.result["warning"] == nil)
    }

    // MARK: - Refused

    @Test func textsOverApplesLimitsAreRefused() async throws {
        let outcome = try await propose(newYear(["texts": ["en-US": [
            "name": .string(String(repeating: "a", count: 31)),
            "shortDescription": .string(String(repeating: "b", count: 51)),
            "longDescription": .string(String(repeating: "c", count: 121)),
        ]]]))
        #expect(outcome.result["status"] == "refused")
        #expect(Self.reasons(outcome) == [
            "en-US · Event Name is 31 characters; the limit is 30.",
            "en-US · Short Description is 51 characters; the limit is 50.",
            "en-US · Long Description is 121 characters; the limit is 120.",
        ])
        #expect(changes.changes.isEmpty)
        #expect(outcome.logLines.first?.outcome == .refused)
    }

    @Test func aPriceOrAllCapitalsInTheTextsIsRefused() async throws {
        let outcome = try await propose(newYear(["texts": ["en-US": [
            "name": "NEW YEAR CHALLENGE",
            "shortDescription": "All of Alba Pro for $4.99",
            "longDescription": "Pick the topics that move you and build a 30-day streak.",
        ]]]))
        #expect(outcome.result["status"] == "refused")
        let reason = try #require(Self.reasons(outcome).first)
        #expect(reason.hasPrefix("en-US · App Review rejects specific prices in In-App Event texts (Guideline 2.3.13): “$4.99”."))
        #expect(reason.contains("Apple asks In-App Event texts to avoid all capitals and repeated punctuation"))
        #expect(changes.changes.isEmpty)
    }

    @Test func anEventLongerThan31DaysIsRefused() async throws {
        let outcome = try await propose(newYear(["eventEnd": "2027-02-01T00:00:01Z"]))
        #expect(Self.reasons(outcome) == ["An event can last 31 days at most. End it sooner or start it later."])
        #expect(changes.changes.isEmpty)
    }

    @Test func aCardShownMoreThan14DaysAheadIsRefused() async throws {
        let outcome = try await propose(newYear(["publishStart": "2026-12-17T23:59:00Z"]))
        #expect(Self.reasons(outcome) == ["The card can show at most 14 days before the event starts. Show it from later."])
        #expect(changes.changes.isEmpty)
    }

    @Test func anEventThatAlreadyStartedIsRefused() async throws {
        let outcome = try await propose(newYear([
            "publishStart": "2026-11-01T00:00:00Z", "eventStart": "2026-11-10T00:00:00Z", "eventEnd": "2026-11-20T00:00:00Z",
        ]))
        #expect(Self.reasons(outcome) == ["The event has to start in the future. Move its dates later."])
        #expect(changes.changes.isEmpty)
    }

    @Test func anInvalidDeepLinkIsRefused() async throws {
        let outcome = try await propose(newYear(["deepLink": "open alba"]))
        #expect(Self.reasons(outcome).first?.hasPrefix("The deep link isn’t a valid URL.") == true)
        #expect(changes.changes.isEmpty)
    }

    @Test func aReferenceNameAnEventHasIsRefused() async throws {
        let outcome = try await propose(newYear(["appId": "Lumen Journal", "referenceName": "winter reflection 2026"]))
        #expect(Self.reasons(outcome).first?.hasSuffix("is taken by another event. Choose another name.") == true)
        #expect(changes.changes.isEmpty)
    }

    @Test func aReferenceNameSomeoneElseQueuedIsRefused() async throws {
        let builder = InAppEventChangeBuilder(appID: Self.alba.id)
        var mine = NewInAppEvent(now: Data.now)
        mine.referenceName = "New Year Challenge 2027"
        try changes.upsert(#require(builder.newEventChange(mine)))

        let outcome = try await propose(newYear())
        #expect(outcome.result["status"] == "refused")
        #expect(Self.reasons(outcome).first?.hasPrefix("“New Year Challenge 2027” is taken by another event") == true)
        #expect(changes.changes.count == 1)
        #expect(changes.changes.first?.source == .you)
        // Another assistant's is left to it too.
        let other = try await propose(newYear(["referenceName": "Spring 2027"]), client: "Codex")
        #expect(other.result["status"] == "queued")
        let again = try await propose(newYear(["referenceName": "Spring 2027"]))
        #expect(again.result["status"] == "refused")
    }

    @Test func textsInAnUnknownLanguageOrMissingOneAreRefused() async throws {
        let outcome = try await propose(newYear(["texts": [
            "xx-XX": ["name": "A", "shortDescription": "B", "longDescription": "C"],
            "pt-BR": ["name": "Ano Novo, Nova Mente", "shortDescription": "Uma frase por manhã"],
        ]]))
        #expect(Self.reasons(outcome) == [
            "pt-BR · longDescription is empty: send all three texts.",
            "“xx-XX” isn’t an App Store locale code, e.g. en-US.",
        ])
        #expect(changes.changes.isEmpty)
    }

    @Test func anUnknownTerritoryIsRefused() async throws {
        let outcome = try await propose(newYear(["territories": ["USA", "Narnia"]]))
        #expect(Self.reasons(outcome) == ["“Narnia” isn’t a country or region code. Use App Store Connect’s, e.g. USA or BRA."])
    }

    @Test func everyReasonIsListedAtOnce() async throws {
        let outcome = try await propose(newYear([
            "referenceName": .string(String(repeating: "n", count: 65)), "eventEnd": "2027-03-01T00:00:00Z", "deepLink": "nope",
        ]))
        #expect(Self.reasons(outcome).count == 3)
    }

    @Test func anUnknownBadgeOrADateWithoutATimeIsAnArgumentError() async {
        await #expect(throws: MCPToolError.self) {
            _ = try await propose(newYear(["badge": "FESTIVAL"]))
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await propose(newYear(["purchaseRequirement": "SUBSCRIPTION"]))
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await propose(newYear(["eventStart": "2027-01-01"]))
        }
        await #expect(throws: MCPToolError.self) {
            _ = try await propose(newYear(["primaryLocale": "klingon"]))
        }
        #expect(changes.changes.isEmpty)
    }

    @Test func proposingStoreTextCanBeTurnedOff() async throws {
        let outcome = try await call(ProposeInAppEventTool(now: { Data.now }), newYear(), allowed: [.prices])
        #expect(outcome.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    // MARK: - Toolbox

    @Test func theToolIsInTheToolboxFreeAndInTheInstructions() {
        #expect(MCPToolbox.standard.toolNames.contains("propose_in_app_event"))
        #expect(ProAssistantGate.refusal(forTool: "propose_in_app_event", isPro: false) == nil)
        let definition = ProposeInAppEventTool().definition
        #expect(definition.proposalKind == .storeText)
        #expect(!definition.isReadOnly)
        let badges = definition.inputSchema["properties"]?["badge"]?["enum"]?.arrayValue?.compactMap(\.stringValue)
        #expect(badges == ["LIVE_EVENT", "PREMIERE", "CHALLENGE", "COMPETITION", "NEW_SEASON", "MAJOR_UPDATE", "SPECIAL_EVENT"])
        let purchases = definition.inputSchema["properties"]?["purchaseRequirement"]?["enum"]?.arrayValue?.compactMap(\.stringValue)
        #expect(purchases == ["NO_COST_ASSOCIATED", "IN_APP_PURCHASE"])
        #expect(MCPEndpoint.instructions.contains("propose a new one with propose_in_app_event, write the missing languages with propose_event_texts"))
    }
}
