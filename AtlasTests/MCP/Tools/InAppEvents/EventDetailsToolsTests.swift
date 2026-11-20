//
//  EventDetailsToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `propose_event_details`, `report_deep_link_check` and what
/// `get_in_app_events` says an event still needs before App Review: Alba
/// 1.2.0's three events had no deep link, and App Store Connect refused
/// the submission.
@MainActor
@Suite("In-App Events MCP · details and deep links")
struct EventDetailsToolsTests {
    typealias Data = InAppEventsTestData

    private let store = InAppEventsStore()
    private let changes = ChangeQueue()
    private let claims = ProjectLinkClaimsCenter()

    /// Winter with every language written: only its details are left.
    private static var ready: InAppEvent {
        var event = Data.winter
        event.localizations.removeLast()
        return event
    }

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], events: [InAppEvent] = [ready], allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private var getTool: GetInAppEventsTool {
        GetInAppEventsTool(store: store, directory: EventArtworkTestFiles.directory(), linkClaims: claims, now: { Data.now })
    }

    private func readEvent(_ events: [InAppEvent] = [ready]) async throws -> JSONValue {
        try #require(try await call(getTool, ["appId": "Lumen Journal"], events: events).result["events"]?.arrayValue?.first)
    }

    private func check(_ link: String, opens: Bool = true, build: String = "1.4 (212)") -> [String: JSONValue] {
        [
            "appId": "Lumen Journal", "eventId": "winter", "deepLink": .string(link), "opens": .bool(opens),
            "shows": "The Winter challenge, on today’s prompt", "beforeStart": "The challenge with “Starts Dec 1”",
            "needsPremium": false, "where": "Lumen/LumenApp.swift:48", "build": .string(build), "testedInSimulator": true,
            "problems": opens ? [] : ["LumenApp has no onOpenURL."],
        ]
    }

    @Test func theToolsAreInTheToolboxAndTheInstructions() {
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: ["propose_event_details", "report_deep_link_check"]))
        #expect(ProposeEventDetailsTool().definition.proposalKind == .storeText)
        #expect(!ReportDeepLinkCheckTool().definition.isReadOnly)
        #expect(MCPEndpoint.instructions.contains("propose_event_details"))
        #expect(MCPEndpoint.instructions.contains("report_deep_link_check"))
        #expect(ProposeInAppEventTool().definition.description.contains("won't take it to App Review until it has one"))
    }

    /// The three details always there, null when App Store Connect has
    /// none; what's missing, item by item.
    @Test func getInAppEventsSaysWhatAppReviewStillNeeds() async throws {
        var bare = Self.ready
        bare.deepLink = nil
        bare.purpose = nil
        let event = try await readEvent([bare])
        #expect(event["deepLink"] == .null)
        #expect(event["purpose"] == .null)
        #expect(event["priority"] == "NORMAL")
        #expect(event["primaryLocale"] == "en-US")
        #expect(event["readyForReview"] == false)
        let missing = try #require(event["missingForReview"]?.arrayValue)
        #expect(missing.compactMap { $0["item"]?.stringValue } == ["deepLink", "purpose"])
        #expect(missing[0]["state"] == "missing")
        #expect(missing[0]["fix"]?.stringValue?.contains("lumen://event") == true)
        #expect(event["deepLinkClaim"]?["state"] == "noDeepLink")
        #expect(event["deepLinkCheck"] == .null)

        let ready = try await readEvent()
        #expect(ready["deepLink"] == "lumen://challenge/winter")
        #expect(ready["purpose"] == "APPROPRIATE_FOR_ALL_USERS")
        #expect(ready["readyForReview"] == true)
        // The project folder isn't read yet.
        #expect(ready["deepLinkClaim"]?["state"] == "notReadYet")
        #expect(ready["missingForReview"]?.arrayValue?.isEmpty == true)
    }

    @Test func aDeepLinkTheProjectDoesntClaimIsMissing() async throws {
        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(domains: ["lumen.app"], targets: ["Lumen"], build: "1.4 (212)")), for: Data.app.id)
        let event = try await readEvent()
        let claim = try #require(event["deepLinkClaim"])
        #expect(claim["state"] == "notClaimed")
        #expect(claim["message"] == "Lumen Journal doesn’t open lumen:// links yet")
        #expect(claim["schemes"]?.arrayValue?.isEmpty == true)
        #expect(claim["applinksDomains"]?.arrayValue == ["lumen.app"])
        #expect(claim["projectBuild"] == "1.4 (212)")
        #expect(claim["projectFolder"] == "/Lumen")
        #expect(event["missingForReview"]?.arrayValue?.compactMap { $0["item"]?.stringValue } == ["linkNotClaimed"])
        #expect(event["readyForReview"] == false)
    }

    @Test func detailsAreQueuedWaitingForThePerson() async throws {
        var bare = Self.ready
        bare.deepLink = nil
        let outcome = try await call(ProposeEventDetailsTool(store: store, now: { Data.now }), [
            "appId": "Lumen Journal", "eventId": "winter", "deepLink": "lumen://challenge/winter-2026", "purpose": "ATTRACT_NEW_USERS",
            "primaryLocale": "en-us", "reason": "LumenApp opens lumen://challenge/<id> on the challenge.",
        ], events: [bare])
        #expect(outcome.result["status"] == "queued")
        let queued = try #require(outcome.result["queued"]?.arrayValue)
        #expect(queued.compactMap { $0["detail"]?.stringValue } == ["deepLink", "purpose"])
        // en-US is what App Store Connect has already.
        #expect(outcome.result["unchanged"]?.arrayValue == ["primaryLocale"])
        #expect(outcome.result["next"]?.stringValue?.contains("report_deep_link_check") == true)
        let change = try #require(changes.change(id: "inAppEvents.\(Data.app.id).winter.details.deepLink"))
        #expect(change.awaitingAcceptance != nil)
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.groupNote == "LumenApp opens lumen://challenge/<id> on the challenge.")

        let event = try await readEvent([bare])
        #expect(event["queuedDetails"]?["deepLink"]?["value"] == "lumen://challenge/winter-2026")
        #expect(event["queuedDetails"]?["deepLink"]?["waitingForAcceptance"] == true)
        #expect(event["missingForReview"]?.arrayValue?.first?["state"] == "suggested")
    }

    @Test(arguments: [
        (["deepLink": "lumen challenge"], "deepLink: The deep link isn’t a valid URL."),
        (["deepLink": "http://lumen.app/winter"], "deepLink: Links that start with http:// open in Safari"),
        (["purpose": "EVERYONE"], "purpose: “EVERYONE” isn’t a purpose."),
        (["priority": "LOW"], "priority: “LOW” isn’t a priority. Use HIGH or NORMAL."),
        (["primaryLocale": "fr-FR"], "primaryLocale: “Winter Reflection 2026” isn’t written in fr-FR"),
        ([:], "Send at least one of deepLink, purpose, priority, primaryLocale, publishStart, eventStart or eventEnd."),
    ] as [([String: String], String)])
    func aValueAppStoreConnectWouldRefuseIsRefusedWithTheFix(values: [String: String], reason: String) async throws {
        var arguments: [String: JSONValue] = ["appId": "Lumen Journal", "eventId": "winter", "reason": "Because."]
        for (key, value) in values { arguments[key] = .string(value) }
        let outcome = try await call(ProposeEventDetailsTool(store: store, now: { Data.now }), arguments)
        #expect(outcome.result["status"] == "refused")
        let reasons = outcome.result["reasons"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(reasons.contains { $0.hasPrefix(reason) }, "\(reasons)")
        #expect(changes.changes(for: Data.app.id, section: .inAppEvents).isEmpty)
    }

    @Test func aPublishedEventsDetailsCantChange() async throws {
        let outcome = try await call(ProposeEventDetailsTool(store: store, now: { Data.now }), [
            "appId": "Lumen Journal", "eventId": "update", "priority": "HIGH", "reason": "Because.",
        ], events: Data.events)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reasons"]?.arrayValue?.first?.stringValue?.contains("only a draft") == true)
    }

    @Test func aCheckIsKeptForItsDeepLinkAndShown() async throws {
        let outcome = try await call(ReportDeepLinkCheckTool(store: store, now: { Data.now }), check("lumen://challenge/winter"))
        #expect(outcome.result["status"] == "saved")
        #expect(outcome.result["shows"] == "Opens the event · checked by Claude Code in build 1.4 (212), tried in Simulator")
        #expect(outcome.result["note"] == nil)
        let report = try #require(store.deepLinkReport(for: Data.app.id, eventID: "winter", deepLink: "lumen://challenge/winter"))
        #expect(report.location == "Lumen/LumenApp.swift:48")
        #expect(report.buildNumber == "212")

        let event = try await readEvent()
        let json = try #require(event["deepLinkCheck"])
        #expect(json["opens"] == true)
        #expect(json["build"] == "1.4 (212)")
        #expect(json["where"] == "Lumen/LumenApp.swift:48")
        #expect(json["by"] == "Claude Code")

        // Another deep link proposed: the check of the old one goes.
        _ = try await call(ProposeEventDetailsTool(store: store, now: { Data.now }), [
            "appId": "Lumen Journal", "eventId": "winter", "deepLink": "lumen://challenges/2026", "reason": "Because.",
        ])
        #expect(store.deepLinkReport(for: Data.app.id, eventID: "winter", deepLink: "lumen://challenge/winter") == nil)
        #expect(try await readEvent()["deepLinkCheck"] == .null)
    }

    @Test func aCheckOfAnotherLinkWaitsForIt() async throws {
        let outcome = try await call(ReportDeepLinkCheckTool(store: store, now: { Data.now }), check("lumen://challenges/2026", opens: false))
        #expect(outcome.result["shows"] == "Doesn’t open it yet")
        #expect(outcome.result["note"]?.stringValue?.contains("propose_event_details") == true)
        // Not shown until the event has that deep link.
        #expect(try await readEvent()["deepLinkCheck"] == .null)
    }

    @Test func aCheckNeedsALinkAndABuild() async throws {
        let badLink = try await call(ReportDeepLinkCheckTool(store: store), check("lumen challenge"))
        #expect(badLink.result["status"] == "refused")
        #expect(badLink.result["reason"]?.stringValue?.hasPrefix("deepLink: The deep link isn’t a valid URL.") == true)
        let badBuild = try await call(ReportDeepLinkCheckTool(store: store), check("lumen://challenge/winter", build: "1.2.0 ()"))
        #expect(badBuild.result["status"] == "refused")
        #expect(badBuild.result["reason"] == "build: give the version and build number checked, like 1.2.0 (21).")
        #expect(store.deepLinkReport(for: Data.app.id, eventID: "winter", deepLink: "lumen://challenge/winter") == nil)
    }

    @Test func aFreeEventThatLandsOnPremiumIsWarned() async throws {
        var arguments = check("lumen://challenge/winter")
        arguments["needsPremium"] = true
        let outcome = try await call(ReportDeepLinkCheckTool(store: store), arguments)
        #expect(outcome.result["warning"]?.stringValue?.contains("NO_COST_ASSOCIATED") == true)
    }
}
