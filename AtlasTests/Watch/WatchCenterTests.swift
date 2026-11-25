//
//  WatchCenterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// One check end to end: what it plans, the one run it starts through the
/// pretend helper (never asking for a folder), the History, what the
/// person decides, and the record saved per app.
@MainActor
@Suite("Look for Improvements · center")
struct WatchCenterTests {
    private typealias Data = WatchTestData
    private let clock = TestClock(WatchTestData.date(hour: 12))
    private let runner = FakeUnixScriptRunner()
    private let asked = ClaudeCodeTestFixtures.FolderRequests()
    private let launcher: ClaudeCodeLauncher
    private let center = WatchCenter()

    init() {
        runner.exitStatus = nil
        let assistants = MCPTestFixtures.controller(server: FakeLocalHTTPServer(), clock: clock)
        launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner, clock: clock, asked: asked)
        let testClock = clock
        center.now = { testClock.now }
        center.calendar = Data.calendar
    }

    private var context: WatchContext {
        var context = Data.context
        context.activeRunCount = launcher.activeRuns.count
        return context
    }

    // MARK: - Planning

    @Test func offOrFreeTheChecksStillRunButNoRunStarts() {
        var off = context
        off.isOn = false
        let plan = center.plan([Data.whatsNewInputs()], context: off)
        let app = plan.apps.first
        #expect(app?.toSend.map(\.kind) == [.whatsNewMissing])
        #expect(app?.refusal == .turnedOff)
        #expect(app?.prompt == nil)
        #expect(center.record(Data.signal().identity, appID: Data.lumen)?.state == .new)

        var free = context
        free.isPro = false
        #expect(center.plan([Data.whatsNewInputs()], context: free).apps.first?.refusal == .notPro)
    }

    @Test func localOnlyFindingsNeedNoRun() {
        var inputs = WatchInputs(appID: Data.tempo, appName: "Tempo", now: clock.now)
        inputs.version = WatchInputs.Version(id: "t21", versionString: "2.1", phase: .prepare)
        inputs.blockers = [.ageRating]
        let app = center.plan([inputs], context: context).apps.first
        #expect(app?.decisions.map(\.verdict) == [.localOnly])
        #expect(app?.refusal == nil)
        #expect(app?.startsRun == false)
    }

    @Test func oneRunPerCheckTheNextAppWaits() {
        let plan = center.plan([Data.whatsNewInputs(), Data.whatsNewInputs(app: Data.tempo)], context: context)
        #expect(plan.apps.map(\.startsRun) == [true, false])
        #expect(plan.apps.last?.refusal == .anotherRunActive)
        #expect(plan.apps.first?.prompt?.contains("Lumen Journal") == true)
    }

    // MARK: - Running

    @Test func aCheckStartsOneWatchRunAndKeepsItInTheHistory() async throws {
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: Data.lumen)
        await launcher.refreshHelper()
        let plan = await center.check([Data.whatsNewInputs()], context: context, suggestions: nil, launcher: launcher)
        #expect(plan.apps.first?.startsRun == true)
        let entry = try #require(center.history(for: Data.lumen).first)
        #expect(launcher.run(entry.id)?.purpose == .watch)
        #expect(entry.signals.map(\.kind) == [.whatsNewMissing])
        #expect(entry.result == .working)
        #expect(center.record(Data.signal().identity, appID: Data.lumen)?.state == .sent(runID: entry.id, date: clock.now))
        #expect(center.lastPlan == plan)
        #expect(asked.requests.isEmpty)

        // The next check: the run is going, and the finding was sent.
        clock.advance(by: 3600)
        let next = await center.check([Data.whatsNewInputs()], context: context, suggestions: nil, launcher: launcher)
        #expect(next.apps.first?.decisions.first?.verdict == .skip(.alreadySent))
        #expect(center.history(for: Data.lumen).count == 1)
        launcher.stop(entry.id)
        await ClaudeCodeTestFixtures.waitForEnd(of: entry.id, in: launcher)
    }

    @Test func aRunNeverAsksForAProjectFolder() async {
        await launcher.refreshHelper()
        let plan = center.plan([Data.whatsNewInputs()], context: context)
        #expect(plan.apps.first?.startsRun == true)
        await center.start(plan, launcher: launcher)
        #expect(asked.requests.isEmpty)
        #expect(launcher.activeRuns.isEmpty)
        #expect(center.history(for: Data.lumen).isEmpty)
    }

    @Test func aRunAtlasNoLongerHasEndedWithAtlasAndItsFindingsGoAgain() {
        let runID = UUID()
        let signal = Data.signal()
        var archive = WatchArchive()
        WatchLedger.observe([signal], in: &archive, now: clock.now)
        WatchLedger.markSent([signal], runID: runID, in: &archive, now: clock.now)
        archive.append(WatchHistoryEntry(id: runID, appID: Data.lumen, appName: "Lumen", startedAt: clock.now, signals: [signal]))
        center.load(archive, for: Data.lumen)

        center.noteEndedRuns(in: launcher)
        #expect(center.history(for: Data.lumen).first?.result == .interrupted)
        center.settle([Data.lumen: [signal]], suggestions: nil)
        #expect(center.record(signal.identity, appID: Data.lumen)?.state == .new)
        #expect(center.history(for: Data.lumen).first?.isSettled == true)
        #expect(center.archive(for: Data.lumen).stats(for: .whatsNewMissing).batches.isEmpty)
    }

    @Test func aFinishedRunSettlesOnceEveryFindingHasAnOutcome() {
        let runID = UUID()
        let fixed = Data.signal()
        let crash = Data.signal(.crashesWorse, subject: "1.4")
        var archive = WatchArchive()
        WatchLedger.observe([fixed, crash], in: &archive, now: clock.now)
        WatchLedger.markSent([fixed, crash], runID: runID, in: &archive, now: clock.now)
        archive.append(WatchHistoryEntry(
            id: runID, appID: Data.lumen, appName: "Lumen", startedAt: clock.now, endedAt: clock.now, signals: [fixed, crash], result: .finished
        ))
        center.load(archive, for: Data.lumen)

        // The crash finding is still found and undecided: nothing yet.
        center.settle([Data.lumen: [crash]], suggestions: nil)
        #expect(center.history(for: Data.lumen).first?.isSettled == false)

        center.dismiss(crash.identity, appID: Data.lumen)
        center.settle([Data.lumen: [crash]], suggestions: nil)
        let stats = center.archive(for: Data.lumen)
        #expect(center.history(for: Data.lumen).first?.isSettled == true)
        #expect(stats.stats(for: .whatsNewMissing).batches.map(\.accepted) == [1])
        #expect(stats.stats(for: .crashesWorse).batches.map(\.dismissed) == [1])
        #expect(center.record(fixed.identity, appID: Data.lumen)?.state == .accepted(date: clock.now))
    }

    @Test func aTaggedWhatsNewSuggestionAcceptedCountsForTheRun() throws {
        let runID = UUID()
        let store = FieldSuggestionStore(now: { Data.now })
        let german = try #require(StoreLocaleCatalog.locale(code: "de-DE"))
        let added = store.add(
            appID: Data.lumen, target: .storePage(german, .whatsNew), value: "Neu", reason: "Commits", source: .assistant(client: "Claude Code"),
            origin: .watch(runID: runID)
        )
        let signal = Data.signal()
        #expect(WatchCenter.evidence(for: signal, runID: runID, in: store).open == 1)
        #expect(WatchCenter.evidence(for: signal, runID: UUID(), in: store) == WatchOutcomes.Suggestions())
        store.markAccepted(added.suggestion, previousValue: "")
        #expect(WatchCenter.evidence(for: signal, runID: runID, in: store).accepted == 1)
    }

    @Test func aRunsProposalsGoOnItsEntry() {
        let runID = UUID()
        var archive = WatchArchive()
        archive.append(WatchHistoryEntry(id: runID, appID: Data.lumen, appName: "Lumen", startedAt: clock.now, signals: []))
        center.load(archive, for: Data.lumen)
        let lines = [
            MCPToolOutcome.LogLine(target: "Lumen · de-DE · What’s New", outcome: .proposed),
            MCPToolOutcome.LogLine(target: "Lumen · ja · What’s New", outcome: .refused, reason: "Too long"),
        ]
        center.noteProposal(origin: .watch(runID: runID), tool: "suggest_fields", lines: lines)
        center.noteProposal(origin: .watch(runID: UUID()), tool: "suggest_fields", lines: lines)
        let proposals = center.history(for: Data.lumen).first?.proposals ?? []
        #expect(proposals.map(\.target) == ["Lumen · de-DE · What’s New"])
        #expect(proposals.map(\.tool) == ["suggest_fields"])
    }

    @Test func theUsageLimitInTheHistoryHoldsRunsBack() {
        var archive = WatchArchive()
        archive.append(WatchHistoryEntry(
            id: UUID(), appID: Data.lumen, appName: "Lumen", startedAt: clock.now.addingTimeInterval(-7200), endedAt: clock.now.addingTimeInterval(-3600),
            signals: [], result: .usageLimit, isSettled: true
        ))
        center.load(archive, for: Data.lumen)
        #expect(center.usageLimitHitAt(launcher: nil) == clock.now.addingTimeInterval(-3600))
    }

    // MARK: - The person

    @Test func notNowDontSuggestAgainAndKeepSuggesting() {
        _ = center.plan([Data.whatsNewInputs()], context: context)
        let identity = Data.signal().identity
        center.notNow(identity, appID: Data.lumen)
        #expect(center.record(identity, appID: Data.lumen)?.state == .snoozed(until: clock.now.addingTimeInterval(7 * Data.day)))

        center.dontSuggestAgain(.crashesWorse, appID: Data.lumen)
        #expect(center.archive(for: Data.lumen).stats(for: .crashesWorse).isSilenced)
        #expect(center.archive(for: Data.tempo).stats(for: .crashesWorse).isSilenced == false)

        center.update(Data.lumen) { archive in
            archive.updateStats(for: .reviewsAfterRelease) { stats in
                stats.isPaused = true
                stats.asksKeepSuggesting = true
            }
        }
        #expect(center.kindsAskingKeepSuggesting(for: Data.lumen) == [.reviewsAfterRelease])
        center.keepSuggesting(.reviewsAfterRelease, appID: Data.lumen, keeps: true)
        #expect(center.kindsAskingKeepSuggesting(for: Data.lumen).isEmpty)
        #expect(!center.archive(for: Data.lumen).stats(for: .reviewsAfterRelease).isPaused)
    }

    @Test func eachAppsRecordIsSavedAndReadBack() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "watch-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let saving = WatchCenter(directory: directory)
        let testClock = clock
        saving.now = { testClock.now }
        _ = saving.plan([Data.whatsNewInputs()], context: context)
        saving.dismiss(Data.signal().identity, appID: Data.lumen)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "watch-\(Data.lumen).json").path))

        let reading = WatchCenter(directory: directory)
        #expect(reading.archive(for: Data.lumen) == saving.archive(for: Data.lumen))
        #expect(reading.record(Data.signal().identity, appID: Data.lumen)?.state == .dismissed(date: clock.now))
        #expect(reading.archive(for: Data.tempo) == WatchArchive())
    }

    @Test func theDebugScenesBuildTheirPlans() {
        for id in WatchDebugScenes.ids {
            #expect(WatchDebugScenes.view(for: id) != nil)
        }
        #expect(WatchDebugScenes.view(for: "nothing") == nil)
    }
}
