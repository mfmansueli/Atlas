//
//  AutopilotRecaptureRunTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A capture-only run: the finished run opened again for some captures.
/// The plan stays, only those captures are asked for and counted, the
/// others are reused, Cancel gives the run back as it was, and the new
/// captures take their slots' places in the set.
@MainActor
@Suite("Autopilot capture-only runs")
struct AutopilotRecaptureRunTests {
    private let center = AutopilotTestFixtures.center()
    private let services: DebugScreenshotsServices
    private let context: AutopilotContext
    private let appID = AutopilotTestFixtures.appID
    /// German on iPhone: the two captures redone.
    private let german = [AutopilotTestFixtures.target("today", .iPhone, "de-DE"), AutopilotTestFixtures.target("week", .iPhone, "de-DE")]

    init() {
        services = AutopilotTestFixtures.services(center)
        context = AutopilotTestFixtures.context(services)
    }

    private var run: AutopilotRun? { center.run(for: appID) }

    /// The small plan finished, every capture in, an hour before now.
    private func installReady(stopsToPick: Bool = false) {
        var plan = AutopilotTestFixtures.smallPlan
        plan.stopsToPick = stopsToPick
        var ready = AutopilotTestFixtures.run(.ready, plan: plan)
        AutopilotTestFixtures.captureAll(&ready)
        ready.finishedAt = AutopilotTestFixtures.now
        var review = AutopilotGuidedReview()
        review.approved = [.screenshots]
        ready.guidedReview = review
        center.install(ready)
        let later = AutopilotTestFixtures.now.addingTimeInterval(3600)
        center.now = { later }
    }

    private func receive(_ target: AutopilotCaptureTarget, id: String) async throws {
        let report = AutopilotCaptureReport(target: target, attempt: 1, score: 0.95, notes: "New phrases")
        _ = try await center.receiveCapture(
            appID: appID, file: AutopilotTestFixtures.file(target.displayType, id: id), report: report, context: context
        )
    }

    // MARK: - Opening

    @Test func openingKeepsThePlanAndAsksOnlyForThoseCaptures() throws {
        installReady()
        let before = try #require(run)
        try center.openRecapture(appID: appID, targets: german, reason: "Phrases rewritten", client: "Claude Code")

        let run = try #require(run)
        #expect(run.stage == .waiting)
        #expect(run.plan == before.plan, "Plan, template and captions stay")
        #expect(run.recapture?.targets == german)
        #expect(run.recapture?.previousReview == before.guidedReview)
        #expect(run.guidedReview == nil)
        #expect(run.finishedAt == nil)
        #expect(run.totalCaptures == 2)
        #expect(run.capturedCount == 0)
        #expect(Set(run.remainingTargets) == Set(german))
        #expect(run.captures.count == before.captures.count, "The other captures are reused")
        #expect(run.uploadToken != before.uploadToken)
        #expect(run.log.last?.text == "Claude Code asked to redo 2 captures in de-DE: Phrases rewritten")
    }

    @Test func itRefusesWithoutAFinishedRun() {
        #expect(throws: AutopilotError.self) { try center.openRecapture(appID: appID, targets: german) }
        center.install(AutopilotTestFixtures.run(.capture))
        #expect(center.recaptureRefusal(appID: appID) != nil)
        #expect(throws: AutopilotError.self) { try center.openRecapture(appID: appID, targets: german) }
    }

    @Test func itRefusesCapturesThePlanDoesntHave() {
        installReady()
        let unknown = AutopilotTestFixtures.target("settings", .iPhone, "de-DE")
        #expect(throws: AutopilotError.self) { try center.openRecapture(appID: appID, targets: [unknown]) }
        #expect(run?.stage == .ready)
    }

    @Test func nextStepAsksOnlyForTheRedoneCaptures() async throws {
        installReady()
        try center.openRecapture(appID: appID, targets: german)
        center.pickUp(appID: appID, client: "Claude Code", environment: nil)
        let step = await center.nextStep(appID: appID, client: AutopilotTestFixtures.client)
        guard case let .capture(targets, _) = step else {
            Issue.record("Expected capture, got \(String(describing: step))")
            return
        }
        #expect(Set(targets).isSubset(of: Set(german)))
        #expect(!targets.isEmpty)
    }

    @Test func aCaptureOutsideTheRunIsRefused() async throws {
        installReady()
        try center.openRecapture(appID: appID, targets: german)
        center.pickUp(appID: appID, client: "Claude Code", environment: nil)
        await #expect(throws: (any Error).self) {
            try await receive(AutopilotTestFixtures.target("today", .iPad, "en-US"), id: "png-x")
        }
    }

    // MARK: - Placing

    @Test func theNewCapturesTakeOnlyTheirSlotsInTheSet() async throws {
        installReady()
        let before = try await services.loadDocument(for: context.app, primaryLocale: context.primaryLocale)
        try center.openRecapture(appID: appID, targets: german)
        center.pickUp(appID: appID, client: "Claude Code", environment: nil)
        try await receive(german[0], id: "png-new-today")
        #expect(run?.stage == .capture)
        try await receive(german[1], id: "png-new-week")

        let run = try #require(run)
        #expect(run.stage == .ready)
        #expect(run.recapture?.placedAt != nil)
        #expect(run.finishedAt != nil)
        #expect(run.log.last?.text == "Redid 2 captures in de-DE · only changed images wait in Review & Push")
        let after = try await services.loadDocument(for: context.app, primaryLocale: context.primaryLocale)
        let changed = Set(after.captures.captures.map(\.id)).subtracting(before.captures.captures.map(\.id))
        #expect(changed == ["png-new-today", "png-new-week"])
        #expect(after.template == before.template)
        // The old German captures of those screens go; the rest stay.
        #expect(run.captures.filter { german.contains($0.target) }.map(\.captureID).sorted() == ["png-new-today", "png-new-week"])
        #expect(run.captures.count == 8)
    }

    @Test func pickShowsOnlyTheRedoneCapturesAndCanKeepTheOneBefore() async throws {
        installReady(stopsToPick: true)
        try center.openRecapture(appID: appID, targets: german)
        center.pickUp(appID: appID, client: "Claude Code", environment: nil)
        try await receive(german[0], id: "png-new-today")
        try await receive(german[1], id: "png-new-week")

        var run = try #require(run)
        #expect(run.stage == .pick)
        #expect(run.recapturePickTargets == german)
        let previous = try #require(run.previousCapture(for: german[0]))
        center.pickRecapture(previous.id, for: german[0], appID: appID)
        run = try #require(self.run)
        #expect(run.finalCapture(for: german[0])?.id == previous.id)
        #expect(run.finalCapture(for: german[1])?.captureID == "png-new-week")

        await center.usePicks(appID: appID, context: context)
        #expect(self.run?.stage == .ready)
    }

    // MARK: - Cancel

    @Test func cancelGivesTheRunBackAsItWas() async throws {
        installReady()
        let before = try #require(run)
        try center.openRecapture(appID: appID, targets: german)
        center.pickUp(appID: appID, client: "Claude Code", environment: nil)
        try await receive(german[0], id: "png-new-today")

        center.cancelRun(appID: appID)

        let run = try #require(run)
        #expect(run.stage == .ready)
        #expect(run.recapture == nil)
        #expect(run.captures.sorted { $0.id < $1.id } == before.captures.sorted { $0.id < $1.id })
        #expect(run.guidedReview == before.guidedReview)
        #expect(run.finishedAt == before.finishedAt)
        #expect(run.log.last?.text == "Stopped redoing 2 captures in de-DE; the set stays as it was")
    }

    @Test func stopAtWaitingAlsoCancels() throws {
        installReady()
        try center.openRecapture(appID: appID, targets: german)
        center.stop(appID: appID)
        #expect(run?.stage == .ready)
        #expect(run?.recapture == nil)
    }

    // MARK: - Resume

    @Test func aRunStoppedWhilePlacingPlacesAgain() throws {
        installReady()
        try center.openRecapture(appID: appID, targets: german)
        center.update(appID) { $0.stage = .localize }
        let run = try #require(run)
        #expect(AutopilotCenter.resume(for: run, isBusy: false) == .placeRecaptures)
    }

    // MARK: - Prompt

    @Test func claudeCodeIsToldItsACaptureOnlyRun() throws {
        installReady()
        try center.openRecapture(appID: appID, targets: german, reason: "phrases rewritten")
        let prompt = try AutopilotPrompt.continuing(#require(run), appName: "Lumen Journal")
        #expect(prompt.contains("Redo only 2 captures in de-DE"))
        #expect(prompt.contains("Why: phrases rewritten."))
    }
}
#endif
