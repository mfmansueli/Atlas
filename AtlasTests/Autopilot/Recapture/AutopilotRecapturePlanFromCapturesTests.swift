//
//  AutopilotRecapturePlanFromCapturesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The plan a capture-only run follows when the app has no saved run
/// (Alba's): screens from the capture files, devices, iPhone Duo poses and
/// sizes from the captures, the open plan's steps and the queued setup;
/// and the run it opens, which Cancel takes away again.
@MainActor
@Suite("Autopilot recapture plan from captures")
struct AutopilotRecapturePlanFromCapturesTests {
    private let center = AutopilotTestFixtures.center()
    private let appID = AutopilotTestFixtures.appID

    private func made(
        _ document: ScreenshotsDocument = AlbaCaptureFixtures.document(), proposals: AutopilotPlanProposals = AutopilotPlanProposals(),
        openPlan: AutopilotPlan? = nil
    ) throws -> AutopilotRecapturePlanFromCaptures {
        try #require(AutopilotRecapturePlanFromCaptures(
            document: document, primaryLocale: "en-US", versionString: "1.2.1", proposals: proposals, openPlan: openPlan
        ))
    }

    // MARK: - The plan

    @Test func screensAreNamedByTheirCaptureFiles() throws {
        let plan = try made().plan
        #expect(plan.screens.map(\.name) == AlbaCaptureFixtures.slotNames)
        #expect(plan.screens.first?.id == "today-s-phrase-1", "As Run Autopilot… names a slot's screen")
        #expect(plan.screens.first?.caption == "Today's phrase headline")
        #expect(plan.screenshotStyle == .keep, "The set keeps its template")
        #expect(!plan.choosesScreens)
        #expect(plan.alsoMakes.makesAppPreview == false)
    }

    @Test func theSetsSlotNamesComeFirst() throws {
        var document = AlbaCaptureFixtures.document()
        document.slotNames = ["Today", "", "Styles", "Streak", "Topics", "Mine"]
        let plan = try made(document).plan
        #expect(plan.screens.map(\.name) == ["Today", "Animated scenes", "Styles", "Streak", "Topics", "Mine"])
    }

    @Test func devicesLanguagesAndDuoPosesFollowTheCaptures() throws {
        let plan = try made().plan
        #expect(plan.displayTypes == [.iPhone, .iPhoneDuo, .iPad])
        #expect(plan.localeCodes == ["en-US", "fr-FR", "ja"])
        #expect(plan.duoSlots(.open) == [0, 2, 4])
        #expect(plan.duoSlots(.closed) == [1, 3, 5])
        #expect(plan.duoPlacement(slot: 1, pose: .closed)?.slot == 1)
        #expect(plan.duoPlacement(slot: 1, pose: .closed)?.isCompanion == false)
        #expect(plan.duoPlacement(slot: 1, pose: .open) == nil)
    }

    @Test func oneDuoPoseEverywhereIsTheDuoRowsChoice() throws {
        var document = AlbaCaptureFixtures.document()
        var captures = CaptureIndex()
        for capture in document.captures.captures {
            var capture = capture
            if capture.displayType == .iPhoneDuo { capture.pixelSize = AlbaCaptureFixtures.duoInner }
            captures.add(capture)
        }
        document.captures = captures
        let plan = try made(document).plan
        #expect(plan.duoScreens == .inner)
        #expect(plan.runChoice.duoSlotPoses == nil)
    }

    @Test func eachCaptureIsTheRunsWithItsSize() throws {
        let fromCaptures = try made()
        let japanese = fromCaptures.captures.filter { $0.target.locale == "ja" }
        #expect(japanese.count == 18)
        let iPad = try #require(japanese.first { $0.target.displayType == .iPad })
        #expect(iPad.pixelSize == AlbaCaptureFixtures.iPad)
        #expect(iPad.captureID == "ja-ipad-1")
        let cover = try #require(japanese.first { $0.target.displayType == .iPhoneDuo && $0.target.duoPose == .closed })
        #expect(cover.pixelSize == AlbaCaptureFixtures.duoCover)
        #expect(fromCaptures.captures.filter { $0.target.locale == "fr-FR" }.count == 6, "fr-FR has only iPhone")
        #expect(fromCaptures.templateVersion == nil)
    }

    @Test func stepsAndSetupComeFromTheOpenPlanAndTheQueuedChanges() throws {
        var open = AutopilotPlan(
            screens: [AutopilotScreen(name: "Streak", steps: "tab “Streak” → wait for the flame")], displayTypes: [.iPhone],
            localeCodes: ["en-US"], primaryLocale: "en-US"
        )
        open.simulator.extraCommands = ["xcrun simctl status_bar booted override --time 9:41"]
        var proposals = AutopilotPlanProposals()
        proposals.changes = [AutopilotPlanChange(
            id: "pc-1", client: "Claude Code", receivedAt: AutopilotTestFixtures.now, sampleData: "launch argument -ui-sample-week"
        )]
        let plan = try made(proposals: proposals, openPlan: open).plan
        #expect(plan.screens[3].steps == "tab “Streak” → wait for the flame")
        #expect(plan.simulator.extraCommands == open.simulator.extraCommands)
        #expect(plan.simulator.sampleDataSteps == "launch argument -ui-sample-week")
    }

    @Test func aSetWithoutCapturesMakesNoPlan() {
        #expect(AutopilotRecapturePlanFromCaptures(document: .empty(primary: "en-US"), primaryLocale: "en-US", versionString: "1.2.1") == nil)
    }

    @Test func theNextPlanDecidesTheDuoRowAgain() throws {
        let fromCaptures = try made()
        let previous = fromCaptures.run(id: "run-1", appID: appID, uploadToken: "token-1", now: AutopilotTestFixtures.now)
        let next = AutopilotPlanner.plan(
            document: nil, live: LiveScreenshots(), primaryLocale: .englishUS, localeCodes: ["en-US"], previous: previous
        )
        #expect(next.runChoice.duoSlotPoses == nil)
    }

    // MARK: - The run

    @Test func openingWithoutARunMakesOneFromTheCaptures() throws {
        let fromCaptures = try made()
        let japanese = fromCaptures.captures.map(\.target).filter { $0.locale == "ja" }
        #expect(center.recaptureRefusal(appID: appID) == nil)
        #expect(center.redoesFromCaptures(appID: appID))

        try center.openRecapture(appID: appID, targets: japanese, reason: "phrases rewritten", client: "Claude Code", fromCaptures: fromCaptures)

        let run = try #require(center.run(for: appID))
        #expect(run.stage == .waiting)
        #expect(run.recapture?.madeFromCaptures == true)
        #expect(run.totalCaptures == 18)
        #expect(run.capturedCount == 0, "The set's captures are the ones redone")
        #expect(Set(run.remainingTargets) == Set(japanese))
        #expect(run.recapture?.previousCaptures.count == 18)
        #expect(run.versionString == "1.2.1")
    }

    @Test func withoutCapturesToMakeItFromItsRefused() {
        let target = AutopilotTestFixtures.target("today", .iPhone, "ja")
        #expect(throws: AutopilotError.self) { try center.openRecapture(appID: appID, targets: [target]) }
        #expect(center.run(for: appID) == nil)
    }

    @Test func aNewPlanNeverStartedIsClosedForIt() throws {
        center.install(AutopilotTestFixtures.run(.plan))
        #expect(center.redoesFromCaptures(appID: appID))
        let fromCaptures = try made()
        let japanese = fromCaptures.captures.map(\.target).filter { $0.locale == "ja" && $0.displayType == .iPhone }
        try center.openRecapture(appID: appID, targets: japanese, fromCaptures: fromCaptures)
        #expect(center.run(for: appID)?.recapture?.targets.count == 6)
    }

    @Test func cancelLeavesTheAppWithNoRunAgain() throws {
        let fromCaptures = try made()
        let japanese = fromCaptures.captures.map(\.target).filter { $0.locale == "ja" }
        try center.openRecapture(appID: appID, targets: japanese, fromCaptures: fromCaptures)
        center.cancelRun(appID: appID)
        #expect(center.run(for: appID) == nil)
    }

    @Test func aCaptureCountsAsInAnyRun() async throws {
        let services = AutopilotTestFixtures.services(center)
        services.documentChange = { $0 = AlbaCaptureFixtures.document() }
        let context = AutopilotTestFixtures.context(services)
        let fromCaptures = try made()
        let target = try #require(fromCaptures.captures.map(\.target).first { $0.locale == "ja" && $0.displayType == .iPhone })
        try center.openRecapture(appID: appID, targets: [target], fromCaptures: fromCaptures)
        center.pickUp(appID: appID, client: "Claude Code", environment: nil)

        let report = AutopilotCaptureReport(target: target, attempt: 1, score: 0.95, notes: "New phrases")
        _ = try await center.receiveCapture(appID: appID, file: AutopilotTestFixtures.file(.iPhone, id: "png-new"), report: report, context: context)

        let run = try #require(center.run(for: appID))
        #expect(run.capturedCount == 1)
        #expect(run.stage == .ready || run.stage == .pick)
        if run.stage == .pick { await center.useRecapturePicks(appID: appID, context: context) }
        let document = try await services.loadDocument(for: context.app, primaryLocale: context.primaryLocale)
        let placed = document.captures.ownCapture(locale: "ja", displayType: .iPhone, slot: 0)
        #expect(placed?.id == "png-new", "Only the redone slot's image changes")
        #expect(document.captures.ownCapture(locale: "ja", displayType: .iPhone, slot: 1)?.id == "ja-iphone-2")
        #expect(center.run(for: appID)?.stage == .ready)
    }
}
#endif
