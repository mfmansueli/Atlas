//
//  AutopilotRecaptureRequestTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Requests to redo captures waiting for the person: what they say, how a
/// newer one takes an older one's captures, and Accept and Decline.
@MainActor
@Suite("Autopilot recapture requests")
struct AutopilotRecaptureRequestTests {
    private let center = AutopilotTestFixtures.center()
    private let appID = AutopilotTestFixtures.appID
    private let today = AutopilotTestFixtures.target("today", .iPhone, "de-DE")
    private let week = AutopilotTestFixtures.target("week", .iPhone, "de-DE")

    private func request(_ id: String, _ targets: [AutopilotCaptureTarget], reason: String = "phrases rewritten in d038b58") -> AutopilotRecaptureRequest {
        AutopilotRecaptureRequest(id: id, client: "Claude Code", receivedAt: AutopilotTestFixtures.now, targets: targets, reason: reason)
    }

    private func installReady() {
        var ready = AutopilotTestFixtures.run(.ready)
        AutopilotTestFixtures.captureAll(&ready)
        center.install(ready)
        let later = AutopilotTestFixtures.now.addingTimeInterval(3600)
        center.now = { later }
    }

    @Test func theHeadlineSaysWhoWhatAndWhy() {
        let eighteen = (0..<18).map { AutopilotTestFixtures.target("s\($0)", .iPhone, "ja") }
        #expect(request("rr-1", eighteen).headline == "Claude Code wants to redo 18 captures in ja: phrases rewritten in d038b58")
        #expect(AutopilotRecaptureRequest.title(captures: 1, locales: ["de-DE"], moments: 0) == "1 capture in de-DE")
        #expect(AutopilotRecaptureRequest.title(captures: 0, locales: [], moments: 1) == "1 App Preview moment")
    }

    @Test func aNewerRequestTakesTheCapturesItAsksForAgain() {
        center.queueRecapture(request("rr-1", [today, week]), appID: appID)
        center.queueRecapture(request("rr-2", [week]), appID: appID)
        let requests = center.recaptureRequests(for: appID)
        #expect(requests.map(\.id) == ["rr-1", "rr-2"])
        #expect(requests[0].targets == [today])

        center.queueRecapture(request("rr-3", [today]), appID: appID)
        #expect(center.recaptureRequests(for: appID).map(\.id) == ["rr-2", "rr-3"], "An emptied request goes")
    }

    @Test func requestsKeepTheProposalsFromBeingEmpty() {
        #expect(center.planProposals(for: appID).isEmpty)
        center.queueRecapture(request("rr-1", [today]), appID: appID)
        #expect(!center.planProposals(for: appID).isEmpty)
        #expect(!center.planProposals(for: appID).isWaiting, "The Plan's Sent for this plan card is only for plan changes")
    }

    @Test func acceptOpensTheCaptureOnlyRun() throws {
        installReady()
        center.queueRecapture(request("rr-1", [today, week]), appID: appID)
        let run = try center.acceptRecapture("rr-1", appID: appID)
        #expect(run.stage == .waiting)
        #expect(run.recapture?.targets == [today, week])
        #expect(run.recapture?.requestID == "rr-1")
        #expect(run.recapture?.reason == "phrases rewritten in d038b58")
        #expect(center.recaptureRequests(for: appID).isEmpty)
    }

    @Test func acceptWhileARunIsGoingKeepsTheRequest() {
        center.install(AutopilotTestFixtures.run(.capture))
        center.queueRecapture(request("rr-1", [today]), appID: appID)
        #expect(throws: AutopilotError.self) { try center.acceptRecapture("rr-1", appID: appID) }
        #expect(center.recaptureRequests(for: appID).map(\.id) == ["rr-1"])
    }

    @Test func declineDropsIt() {
        center.queueRecapture(request("rr-1", [today]), appID: appID)
        center.declineRecapture("rr-1", appID: appID)
        #expect(center.recaptureRequests(for: appID).isEmpty)
    }

    @Test func aRequestSurvivesBeingSaved() throws {
        var proposals = AutopilotPlanProposals()
        proposals.recaptureRequests = [request("rr-1", [today])]
        let data = try JSONEncoder().encode(proposals)
        let decoded = try JSONDecoder().decode(AutopilotPlanProposals.self, from: data)
        #expect(decoded.recaptureRequests == proposals.recaptureRequests)
    }

    @Test func gridCellsBecomeThePlansTargets() {
        let plan = AutopilotTestFixtures.smallPlan
        let targets = AutopilotRecaptureTargets.targets(cells: [("de-DE", .iPhone, 1), ("de-DE", .iPhone, 0)], in: plan)
        #expect(targets == [today, week], "In the plan's order")
        #expect(AutopilotRecaptureTargets.targets(cells: [("fr-FR", .iPhone, 0)], in: plan).isEmpty)
    }
}
#endif
