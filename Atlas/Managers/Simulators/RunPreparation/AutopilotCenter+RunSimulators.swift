//
//  AutopilotCenter+RunSimulators.swift
//  Atlas
//

import Foundation

/// Any run makes the simulators it lacks by itself when only the simulator
/// is missing (the device type and a runtime that runs it are installed):
/// when it opens (Start, a capture-only run accepted or opened by
/// request_recapture, Continue) and mid-run, when next_step or
/// get_capture_plan meets a device without one. A device-wide "no
/// simulator" problem is solved by itself once the simulator is there.
/// Only what Atlas can't do goes to the person: a runtime to download
/// (several GB, the card's Install), an old or missing helper, or a make
/// that failed (its problem says why).
extension AutopilotCenter {
    /// The devices `run` still captures on: its targets not captured or
    /// settled yet, the ones an open problem holds included. Mac's captures
    /// need no simulator.
    static func devicesLeft(in run: AutopilotRun) -> [ScreenshotDisplayType] {
        let left = Set(run.capturingTargets.filter { !run.isSettled($0) }.map(\.displayType))
            .union(run.openProblems.filter(\.isDeviceWide).map(\.target.displayType))
            .subtracting([.mac])
        return run.plan.displayTypes.filter(left.contains)
    }

    // MARK: - When a run opens

    /// Before the run goes to the assistant: checks this Mac's simulators,
    /// makes each one the run's devices lack that can be made (and waits
    /// for it, in the run's log), solves the "no simulator" problems that
    /// now are, and reports the devices that need a download as one
    /// problem each.
    func prepareSimulators(appID: StoreApp.ID, simulators: MacSimulators) async {
        guard let run = runs[appID], run.stage == .waiting || run.stage == .capture, simulators.hasHelper else { return }
        let devices = Self.devicesLeft(in: run)
        guard !devices.isEmpty else { return }
        await simulators.check()
        for display in devices {
            if simulators.maker.mayMake(display) { startMaking(display, appID: appID, simulators: simulators) }
            await simulators.maker.wait(for: display)
        }
        solveMissingSimulatorProblems(appID: appID, simulators: simulators)
        reportMissingSimulators(appID: appID, simulators: simulators)
    }

    // MARK: - Mid-run

    /// next_step and get_capture_plan: starts making each simulator the
    /// run's devices lack that can be made, without waiting, and solves the
    /// "no simulator" problems that now are. The devices being made, for
    /// which the assistant waits.
    @discardableResult
    func makeMissingSimulators(appID: StoreApp.ID, simulators: MacSimulators) async -> [ScreenshotDisplayType] {
        guard let run = runs[appID], run.stage == .waiting || run.stage == .capture, simulators.hasHelper else { return [] }
        let devices = Self.devicesLeft(in: run)
        guard !devices.isEmpty else { return [] }
        let isMaking = devices.contains { simulators.maker.isMaking($0) }
        if !isMaking, Self.needsCheck(devices, of: run, simulators: simulators) { await simulators.check() }
        solveMissingSimulatorProblems(appID: appID, simulators: simulators)
        for display in devices where simulators.maker.mayMake(display) {
            startMaking(display, appID: appID, simulators: simulators)
        }
        return devices.filter { simulators.maker.isMaking($0) }
    }

    /// next_step's answer while a simulator is being made: wait, not report
    /// it.
    static func makingStep(_ devices: [ScreenshotDisplayType]) -> AutopilotNextStep? {
        guard !devices.isEmpty else { return nil }
        let names = devices.map(\.deviceName).formatted(.list(type: .and))
        let reason = String(localized: """
        Atlas is making the \(names) simulator\(devices.count == 1 ? "" : "s") on this Mac (the runtime is installed): \
        don’t report it, and don’t make or boot it yourself. Ask next_step again in a few seconds; it then gives the \
        captures.
        """)
        return .wait(reason: reason, seconds: 10)
    }

    /// What's known could have changed since: not checked yet, a device
    /// without its simulator, or a problem that says so.
    private static func needsCheck(_ devices: [ScreenshotDisplayType], of run: AutopilotRun, simulators: MacSimulators) -> Bool {
        guard simulators.inventory != nil else { return true }
        let missing = devices.contains { display in
            if case .ready = simulators.status(for: display) { return false }
            return true
        }
        return missing || run.openProblems.contains(where: \.isAboutMissingSimulator)
    }

    // MARK: - Solved problems

    /// An open device-wide "no simulator" problem whose device has its
    /// simulator now (or one Atlas is about to make) is solved: its
    /// screens go back to next_step without the person's Retry. Alba's
    /// pr-40a1e4a1 held ten iPhone Duo captures on a Mac with the runtime.
    /// Returns the problems solved.
    @discardableResult
    func solveMissingSimulatorProblems(appID: StoreApp.ID, simulators: MacSimulators) -> [String] {
        guard let run = runs[appID] else { return [] }
        let solved = run.openProblems.filter { problem in
            guard problem.isAboutMissingSimulator else { return false }
            let display = problem.target.displayType
            if case .ready = simulators.status(for: display) { return true }
            return simulators.maker.mayMake(display)
        }
        guard !solved.isEmpty else { return [] }
        let ids = Set(solved.map(\.id))
        update(appID) { run in
            for index in run.problems.indices where ids.contains(run.problems[index].id) {
                run.problems[index].resolution = .solvedByAtlas
            }
            for display in Set(solved.map(\.target.displayType)) {
                let text = String(localized: "\(display.deviceName): its simulator can be captured now, so its screens go on")
                run.appendLog(text, kind: .event, at: now())
            }
        }
        return solved.map(\.id)
    }

    // MARK: - Making

    /// Makes `display`'s simulator in the background, in the run's log;
    /// nothing when it's being made already.
    private func startMaking(_ display: ScreenshotDisplayType, appID: StoreApp.ID, simulators: MacSimulators) {
        let runtime: String? = if case let .canMake(_, _, runtime, _) = simulators.status(for: display) { runtime } else { nil }
        let started = simulators.maker.start(display) { [weak self] outcome in
            self?.finishMaking(display, outcome: outcome, appID: appID, simulators: simulators)
        }
        guard started else { return }
        update(appID) { run in
            let text = String(localized: "\(display.deviceName): no simulator yet, Atlas is making it on \(runtime ?? display.simulatorPlatform)")
            run.appendLog(text, kind: .command, at: now())
        }
    }

    /// Made: in the log, and its problems are solved. Failed: one problem
    /// for the device with what `create-simulator` said, for the person.
    private func finishMaking(_ display: ScreenshotDisplayType, outcome: SimulatorMakeOutcome, appID: StoreApp.ID, simulators: MacSimulators) {
        switch outcome {
        case let .made(runtime):
            update(appID) { $0.appendLog(String(localized: "\(display.deviceName): simulator made on \(runtime)"), kind: .event, at: now()) }
            solveMissingSimulatorProblems(appID: appID, simulators: simulators)
        case let .failed(reason):
            guard let run = runs[appID], let target = run.capturingTargets.first(where: { $0.displayType == display }) else { return }
            _ = try? reportProblem(
                appID: appID, target: target,
                what: String(localized: "Atlas couldn’t make the \(display.deviceName) simulator: \(reason)"),
                proposedFix: String(localized: "Make the \(display.deviceName) simulator in Xcode › Window › Devices and Simulators, then retry."),
                affectsDevice: true
            )
        case .nothingToMake, .busy:
            break
        }
    }
}
