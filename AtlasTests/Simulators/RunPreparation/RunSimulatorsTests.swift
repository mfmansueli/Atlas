//
//  RunSimulatorsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Any run makes a simulator this Mac lacks when only the simulator is
/// missing (`DebugSimulators.Mac(hasNewRuntime: true, hasDuo: false)`: the
/// iPhone Duo device type and iOS 27.2 are there). Alba's capture-only run
/// told the assistant to report iPhone Duo instead (pr-40a1e4a1), and its
/// ten Duo captures waited for the person.
@MainActor
@Suite("Runs make the simulators they lack")
struct RunSimulatorsTests {
    private static let helper = URL(filePath: "/tmp/Start Claude Code.zsh")
    private static let duoType = "com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
    private static let newRuntime = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
    /// What next_step said on Alba's run, and the assistant reported.
    private static let albaProblem = """
    iPhone Duo isn't folded, and Atlas can't fold it by itself now: There’s no iPhone Duo simulator on this Mac yet.
    """

    /// iPhone and iPhone Duo (open and closed) in English and German.
    private static var duoPlan: AutopilotPlan {
        var plan = AutopilotTestFixtures.smallPlan
        plan.displayTypes = [.iPhone, .iPhoneDuo]
        plan.runChoice.duoScreens = .both
        plan.runChoice.duoBoth = .sideBySide
        return plan
    }

    private static func simulators(_ runner: PretendMacRunner) -> MacSimulators {
        let simulators = MacSimulators(runner: runner, helperURL: helper)
        simulators.duo.interval = .zero
        return simulators
    }

    private static func pretendMac(runtime: Bool = true, duo: Bool = false) -> PretendMacRunner {
        PretendMacRunner(DebugSimulators.Mac(hasNewRuntime: runtime, hasDuo: duo))
    }

    private static func madeDuo(_ runner: PretendMacRunner) -> Bool {
        runner.calls("create-simulator") == [["create-simulator", "iPhone Duo", duoType, newRuntime]]
    }

    /// Lumen's finished run with iPhone Duo, opened again for German's
    /// captures; the clock moved past its captures.
    private static func capturingGerman(in fixtures: MCPAutopilotFixtures) throws {
        let later = AutopilotTestFixtures.now.addingTimeInterval(3600)
        fixtures.center.now = { later }
        let german = try #require(fixtures.run).plan.targets.filter { $0.locale == "de-DE" }
        try fixtures.center.openRecapture(appID: MCPAutopilotFixtures.appID, targets: german, client: AutopilotTestFixtures.client)
    }

    private static func readyRun() -> AutopilotRun {
        var run = AutopilotTestFixtures.run(.ready, plan: duoPlan)
        AutopilotTestFixtures.captureAll(&run)
        return run
    }

    // MARK: - When a run opens

    @Test func acceptingARecaptureMakesTheDuoSimulatorFirst() async throws {
        let center = AutopilotTestFixtures.center()
        let appID = AutopilotTestFixtures.appID
        center.install(Self.readyRun())
        center.now = { AutopilotTestFixtures.now.addingTimeInterval(3600) }
        let duo = Self.readyRun().plan.targets.filter { $0.displayType == .iPhoneDuo && $0.locale == "de-DE" }
        center.queueRecapture(AutopilotRecaptureRequest(
            id: "rr-1", client: "Claude Code", receivedAt: AutopilotTestFixtures.now, targets: duo, reason: "phrases rewritten"
        ), appID: appID)
        let runner = Self.pretendMac()
        let simulators = Self.simulators(runner)

        let opened = try center.acceptRecapture("rr-1", appID: appID)
        #expect(opened.stage == .waiting)
        #expect(simulators.inventory == nil, "Not checked before the run opens")
        await center.prepareSimulators(appID: appID, simulators: simulators)

        #expect(Self.madeDuo(runner))
        #expect(simulators.status(for: .iPhoneDuo) == .ready(simulator: "iPhone Duo", runtime: "iOS 27.2"))
        let run = try #require(center.run(for: appID))
        #expect(run.openProblems.isEmpty, "Nothing for the person")
        #expect(run.log.map(\.text).contains("iPhone Duo: simulator made on iOS 27.2"))
        #expect(Set(run.remainingTargets) == Set(duo), "Every Duo capture is the assistant's")
        #expect(runner.calls("install-platform").isEmpty)
    }

    /// Accept (or Capture Again) starts Claude Code through
    /// `AutopilotContinuation.start`: the simulator is made before it.
    @Test func continuingTheRunMakesTheSimulatorBeforeClaudeCodeStarts() async throws {
        let clock = TestClock()
        let runner = FakeUnixScriptRunner()
        runner.answers["simulators"] = [
            [DebugSimulators.json(DebugSimulators.Mac(hasNewRuntime: true, hasDuo: false))],
            [DebugSimulators.json(DebugSimulators.Mac(hasNewRuntime: true, hasDuo: true))],
        ]
        runner.answers["create-simulator"] = [["6F0D2C5E-0A3B-4C1D-9E8F-1A2B3C4D5E6F"]]
        let assistants = MCPTestFixtures.controller(server: FakeLocalHTTPServer(), clock: clock)
        let launcher = ClaudeCodeTestFixtures.launcher(assistants: assistants, runner: runner, clock: clock)
        let appID = ClaudeCodeTestFixtures.lumenID
        launcher.setProjectFolder(ClaudeCodeTestFixtures.lumenFolder, for: appID)
        await launcher.refreshHelper()

        var ready = Self.readyRun()
        ready.appID = appID
        let center = AutopilotCenter(runs: [appID: ready])
        center.now = { AutopilotTestFixtures.now.addingTimeInterval(3600) }
        try center.openRecapture(appID: appID, targets: ready.plan.targets.filter { $0.displayType == .iPhoneDuo })

        let session = await AutopilotContinuation.start(appID: appID, appName: "Lumen Journal", center: center, launcher: launcher)
        #expect(session != nil)
        await ClaudeCodeTestFixtures.waitForHelper(runner)
        let calls = runner.recordedArguments.map { $0.first ?? "" }
        let made = try #require(calls.firstIndex(of: "create-simulator"))
        let started = try #require(calls.firstIndex(of: "run"))
        #expect(made < started, "Made before Claude Code starts")
        #expect(center.run(for: appID)?.openProblems.isEmpty == true)
    }

    // MARK: - Mid-run

    @Test func nextStepWaitsWhileAtlasMakesTheDuoInsteadOfAskingForAReport() async throws {
        var run = AutopilotTestFixtures.run(.capture, plan: Self.duoPlan)
        AutopilotTestFixtures.captureAll(&run, except: Set(run.plan.targets.filter { $0.displayType == .iPhoneDuo }))
        let fixtures = MCPAutopilotFixtures(run)
        let runner = Self.pretendMac()
        let simulators = Self.simulators(runner)
        defer { withExtendedLifetime(simulators) {} }

        let waiting = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        #expect(waiting.result["action"] == "wait")
        let reason = try #require(waiting.result["reason"]?.stringValue)
        #expect(reason.hasPrefix("Atlas is making the iPhone Duo simulator"))
        #expect(!reason.contains("report_capture_problem"))
        #expect(waiting.result["retryAfterSeconds"]?.intValue ?? 0 > 0)
        #expect(waiting.result["making"] == .array(["iphone_duo"]))
        #expect(waiting.result["iPhoneDuo"] == nil)

        await simulators.maker.waitForAll()
        #expect(Self.madeDuo(runner))
        let capture = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        #expect(capture.result["action"] == "capture")
        let duo = try #require(capture.result["targets"]?.arrayValue).filter { $0["displayType"] == "iphone_duo" }
        #expect(!duo.isEmpty)
        #expect(duo.allSatisfy { $0["pose"] == "closed" }, "Its closed screens first, as with any Duo")
        let note = try #require(capture.result["iPhoneDuo"]?.stringValue)
        #expect(note.hasPrefix("iPhone Duo is folded"), "The made Duo is started folded for them")
        #expect(fixtures.run?.openProblems.isEmpty == true)
        #expect(fixtures.run?.log.map(\.text).contains("iPhone Duo: simulator made on iOS 27.2") == true)
    }

    @Test func aMakeUnderWayIsntStartedTwice() async {
        var run = AutopilotTestFixtures.run(.capture, plan: Self.duoPlan)
        AutopilotTestFixtures.captureAll(&run, except: Set(run.plan.targets.filter { $0.displayType == .iPhoneDuo }))
        let fixtures = MCPAutopilotFixtures(run)
        let runner = Self.pretendMac()
        let simulators = Self.simulators(runner)
        defer { withExtendedLifetime(simulators) {} }
        let first = await fixtures.center.makeMissingSimulators(appID: MCPAutopilotFixtures.appID, simulators: simulators)
        let second = await fixtures.center.makeMissingSimulators(appID: MCPAutopilotFixtures.appID, simulators: simulators)
        #expect(first == [.iPhoneDuo])
        #expect(second.allSatisfy { $0 == .iPhoneDuo })
        await simulators.maker.waitForAll()
        #expect(runner.calls("create-simulator").count == 1)
    }

    // MARK: - Problems that became solvable

    /// Alba's case: the capture-only run's iPhone Duo problem, reported
    /// because next_step said to, on a Mac with the runtime.
    @Test func anOpenNoSimulatorProblemIsSolvedOnceAtlasMakesIt() async throws {
        let fixtures = MCPAutopilotFixtures(Self.readyRun())
        try Self.capturingGerman(in: fixtures)
        let runner = Self.pretendMac()
        let simulators = Self.simulators(runner)
        defer { withExtendedLifetime(simulators) {} }
        _ = try await fixtures.call(GetCapturePlanTool(), ["run": "run-1"])
        let duoTarget = try #require(fixtures.run?.plan.targets.first { $0.displayType == .iPhoneDuo && $0.locale == "de-DE" })
        let problem = try fixtures.center.reportProblem(
            appID: MCPAutopilotFixtures.appID, target: duoTarget, what: Self.albaProblem, proposedFix: nil, affectsDevice: true
        )
        #expect(fixtures.run?.remainingTargets.contains { $0.displayType == .iPhoneDuo } == false, "Held for the person")

        let waiting = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        #expect(waiting.result["action"] == "wait")
        await simulators.maker.waitForAll()

        let solved = try #require(fixtures.run?.problems.first { $0.id == problem.id })
        #expect(solved.resolution == .solvedByAtlas)
        #expect(!solved.isOpen)
        let step = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        #expect(step.result["action"] == "capture")
        let duo = try #require(step.result["targets"]?.arrayValue).filter { $0["displayType"] == "iphone_duo" }
        #expect(duo.count == Self.duoPlan.targets.count { $0.displayType == .iPhoneDuo && $0.locale == "de-DE" && Self.duoPlan.duoPose(for: $0) == .closed })
        #expect(duo.allSatisfy { $0["locale"] == "de-DE" && $0["pose"] == "closed" })
        #expect(Self.madeDuo(runner))
    }

    /// The person made it (or it was there all along): solved without
    /// making anything.
    @Test func aNoSimulatorProblemOnADeviceThatHasOneIsSolved() async throws {
        var run = AutopilotTestFixtures.run(.capture, plan: Self.duoPlan)
        AutopilotTestFixtures.captureAll(&run, except: Set(run.plan.targets.filter { $0.displayType == .iPhoneDuo }))
        let fixtures = MCPAutopilotFixtures(run)
        let target = try #require(run.plan.targets.first { $0.displayType == .iPhoneDuo })
        let problem = try fixtures.center.reportProblem(
            appID: MCPAutopilotFixtures.appID, target: target, what: "No iPhone Duo simulator on this Mac.", proposedFix: nil, affectsDevice: true
        )
        let runner = Self.pretendMac(duo: true)
        let simulators = Self.simulators(runner)
        let making = await fixtures.center.makeMissingSimulators(appID: MCPAutopilotFixtures.appID, simulators: simulators)
        #expect(making.isEmpty)
        #expect(fixtures.run?.problems.first { $0.id == problem.id }?.resolution == .solvedByAtlas)
        #expect(runner.calls("create-simulator").isEmpty)
        #expect(fixtures.run?.nextTargets.contains { $0.displayType == .iPhoneDuo } == true)
    }

    // MARK: - Only the person when needed

    @Test func aMissingRuntimeStillGoesToThePersonWithoutInstalling() async throws {
        var run = AutopilotTestFixtures.run(.capture, plan: Self.duoPlan)
        AutopilotTestFixtures.captureAll(&run, except: Set(run.plan.targets.filter { $0.displayType == .iPhoneDuo }))
        let fixtures = MCPAutopilotFixtures(run)
        let runner = Self.pretendMac(runtime: false)
        let simulators = Self.simulators(runner)
        defer { withExtendedLifetime(simulators) {} }

        await fixtures.center.prepareSimulators(appID: MCPAutopilotFixtures.appID, simulators: simulators)
        let problem = try #require(fixtures.run?.openProblems.first)
        #expect(problem.isDeviceWide)
        #expect(problem.target.displayType == .iPhoneDuo)
        #expect(problem.proposedFix == "Install the iOS simulator (xcodebuild -downloadPlatform iOS).")

        let step = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        #expect(step.result["action"] != "wait" || step.result["making"] == nil, "Nothing is being made")
        #expect(fixtures.run?.openProblems.map(\.id) == [problem.id], "Not solved: the runtime isn't there")
        #expect(runner.calls("install-platform").isEmpty, "A download of several GB is the person's Install")
        #expect(runner.calls("create-simulator").isEmpty)
        let plan = try await fixtures.call(GetCapturePlanTool(), ["run": "run-1"], simulators: simulators)
        let duo = try #require(plan.result["devices"]?.arrayValue?.first { $0["displayType"] == "iphone_duo" })
        #expect(duo["simulator"] == "needsRuntime")
    }

    /// With no Duo problem reported yet, the fold note says to report the
    /// missing runtime: Atlas can't make that one.
    @Test func theFoldNoteAsksForAReportOnlyWithoutTheRuntime() async throws {
        let fixtures = MCPAutopilotFixtures(AutopilotTestFixtures.run(.capture, plan: Self.duoPlan))
        let simulators = Self.simulators(Self.pretendMac(runtime: false))
        defer { withExtendedLifetime(simulators) {} }
        let step = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        let note = try #require(step.result["iPhoneDuo"]?.stringValue)
        #expect(note.contains("the runtime it needs isn't installed"))
        #expect(note.contains("affectsDevice"))
    }

    @Test func aFailedMakeIsAProblemWithWhatItSaid() async throws {
        var run = AutopilotTestFixtures.run(.capture, plan: Self.duoPlan)
        AutopilotTestFixtures.captureAll(&run, except: Set(run.plan.targets.filter { $0.displayType == .iPhoneDuo }))
        let fixtures = MCPAutopilotFixtures(run)
        let runner = Self.pretendMac()
        runner.createFailure = "An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=403): Invalid runtime"
        let simulators = Self.simulators(runner)
        defer { withExtendedLifetime(simulators) {} }

        await fixtures.center.prepareSimulators(appID: MCPAutopilotFixtures.appID, simulators: simulators)
        let problem = try #require(fixtures.run?.openProblems.first)
        #expect(problem.isDeviceWide)
        #expect(problem.target.displayType == .iPhoneDuo)
        #expect(problem.what.hasPrefix("Atlas couldn’t make the iPhone Duo simulator: An error was encountered"))
        #expect(problem.what.hasSuffix("Invalid runtime"))

        // It isn't tried again by itself, nor solved, while it can't be made.
        let step = try await fixtures.call(NextStepTool(), ["run": "run-1"], simulators: simulators)
        #expect(step.result["making"] == nil)
        await simulators.maker.waitForAll()
        #expect(runner.calls("create-simulator").count == 1)
        #expect(fixtures.run?.openProblems.map(\.id) == [problem.id])
    }

    // MARK: - get_capture_plan

    @Test func thePlanSaysEachDevicesSimulator() async throws {
        var run = AutopilotTestFixtures.run(.capture, plan: Self.duoPlan)
        AutopilotTestFixtures.captureAll(&run, except: Set(run.plan.targets.filter { $0.displayType == .iPhoneDuo }))
        let fixtures = MCPAutopilotFixtures(run)
        let simulators = Self.simulators(Self.pretendMac())
        defer { withExtendedLifetime(simulators) {} }

        let plan = try await fixtures.call(GetCapturePlanTool(), ["run": "run-1"], simulators: simulators)
        let devices = try #require(plan.result["devices"]?.arrayValue)
        #expect(devices.first { $0["displayType"] == "iphone" }?["simulator"] == "ready")
        let duo = try #require(devices.first { $0["displayType"] == "iphone_duo" })
        #expect(duo["simulator"] == "making", "Atlas started making it")
        #expect(duo["simulatorName"] == "iPhone Duo")
        #expect(duo["how"]?.stringValue?.contains("Atlas makes it itself") == true)

        await simulators.maker.waitForAll()
        let again = try await fixtures.call(GetCapturePlanTool(), ["run": "run-1"], simulators: simulators)
        let made = try #require(again.result["devices"]?.arrayValue?.first { $0["displayType"] == "iphone_duo" })
        #expect(made["simulator"] == "ready")
    }

    @Test func theTextsSayAtlasMakesAMissingSimulator() {
        #expect(MCPEndpoint.instructions.contains("report a device with affectsDevice only when its runtime is missing"))
        #expect(ReportCaptureProblemTool().definition.description.contains("Atlas makes it itself"))
        #expect(AutopilotRun.howToCapture(.iPhoneDuo)?.contains("only when the runtime is missing") == true)
    }

    // MARK: - Pieces

    @Test func problemsAboutAMissingSimulatorAreTold() {
        let duo = AutopilotTestFixtures.target("today", .iPhoneDuo)
        func problem(_ what: String, fix: String? = nil, device: Bool = true) -> AutopilotProblem {
            AutopilotProblem(id: "pr-1", target: duo, what: what, proposedFix: fix, affectsDevice: device ? true : nil, reportedAt: .now)
        }
        #expect(problem(Self.albaProblem).isAboutMissingSimulator)
        #expect(problem("This Mac can’t run the iPhone Duo simulator. Needs the iOS 27.1 simulator or later.").isAboutMissingSimulator)
        #expect(problem("The iPhone Duo simulator isn't installed.").isAboutMissingSimulator)
        #expect(problem("Can't capture iPhone Duo.", fix: "xcrun simctl create \"iPhone Duo\" …").isAboutMissingSimulator)
        #expect(!problem("iPhone Duo's SpringBoard crashed and xcrun simctl launch hangs (stuck).").isAboutMissingSimulator)
        #expect(!problem("iPhone Duo isn't open: its inner display is black.").isAboutMissingSimulator)
        #expect(!problem(Self.albaProblem, device: false).isAboutMissingSimulator, "One screen's problem is the person's")
    }

    @Test func readinessFollowsTheStatus() {
        #expect(SimulatorReadiness(.ready(simulator: "iPhone Duo", runtime: "iOS 27.2")) == .ready)
        #expect(SimulatorReadiness(.canMake(deviceType: "iPhone Duo", deviceTypeID: Self.duoType, runtime: "iOS 27.2", runtimeID: Self.newRuntime)) == .making)
        #expect(SimulatorReadiness(.needsRuntime(platform: "iOS", minimumVersion: "27.1", installed: [])) == .needsRuntime)
        #expect(SimulatorReadiness(.needsNewerXcode(deviceName: "iPhone Duo")) == .needsRuntime)
        #expect(SimulatorReadiness(nil) == nil)
        #expect(SimulatorReadiness(nil, isMaking: true) == .making)
        let canMake = SimulatorStatus.canMake(deviceType: "iPhone Duo", deviceTypeID: Self.duoType, runtime: "iOS 27.2", runtimeID: Self.newRuntime)
        #expect(SimulatorReadiness(canMake, failed: true) == .couldntMake)
    }
}
#endif
