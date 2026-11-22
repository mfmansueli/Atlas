//
//  SimulatorMaker.swift
//  Atlas
//

import Foundation
import Observation

/// Makes a device's simulator on its own during any Autopilot run, when the
/// device type and a runtime that runs it are installed and only the
/// simulator is missing (`SimulatorStatus.canMake`). Alba's capture-only
/// run had iPhone Duo's type and the iOS 27.2 runtime, but only the Start
/// check made simulators, so its ten Duo captures waited for the person.
/// One make per device at a time: a second ask joins the one under way. A
/// make that failed isn't tried again on its own (its problem says why);
/// the person's Make the Simulator still can. Owned lazily by
/// `MacSimulators.maker`, which it holds weakly.
@MainActor
@Observable
final class SimulatorMaker {
    /// The devices whose simulator is being made now.
    private(set) var making: Set<ScreenshotDisplayType> = []
    /// Why the last make of each device failed.
    private(set) var failures: [ScreenshotDisplayType: String] = [:]

    @ObservationIgnored private weak var simulators: MacSimulators?
    @ObservationIgnored private var tasks: [ScreenshotDisplayType: Task<SimulatorMakeOutcome, Never>] = [:]
    /// How long a make waits for the person's own install or make to end.
    @ObservationIgnored var busyLimit: Duration = .seconds(120)

    init(simulators: MacSimulators) {
        self.simulators = simulators
    }

    func isMaking(_ display: ScreenshotDisplayType) -> Bool {
        making.contains(display) || simulators?.working == display
    }

    /// Atlas may make `display`'s simulator now by itself: only the
    /// simulator is missing, and making it didn't fail before.
    func mayMake(_ display: ScreenshotDisplayType) -> Bool {
        guard failures[display] == nil, case .canMake = simulators?.status(for: display) else { return false }
        return true
    }

    /// Starts making `display`'s simulator; `then` gets how it ended, before
    /// anyone waiting on it (`wait(for:)`) goes on. False when one is being
    /// made already: `then` isn't called, the make under way goes on.
    @discardableResult
    func start(_ display: ScreenshotDisplayType, then: @escaping @MainActor (SimulatorMakeOutcome) async -> Void = { _ in }) -> Bool {
        guard tasks[display] == nil else { return false }
        making.insert(display)
        tasks[display] = Task { [weak self] in
            guard let self else { return .nothingToMake(nil) }
            let outcome = await make(display)
            await then(outcome)
            tasks[display] = nil
            making.remove(display)
            return outcome
        }
        return true
    }

    /// Waits for the make of `display` under way, if any; how it ended.
    @discardableResult
    func wait(for display: ScreenshotDisplayType) async -> SimulatorMakeOutcome? {
        guard let task = tasks[display] else { return nil }
        return await task.value
    }

    /// Checks this Mac's simulators and makes `display`'s when only the
    /// simulator is missing, or waits for the make under way: how it
    /// ended, nil when there was nothing to make. A product page's
    /// captures, which have no Autopilot run.
    @discardableResult
    func makeIfMissing(_ display: ScreenshotDisplayType) async -> SimulatorMakeOutcome? {
        guard let simulators, simulators.hasHelper, display != .mac else { return nil }
        if !isMaking(display) { await simulators.check() }
        if mayMake(display) { start(display) }
        return await wait(for: display)
    }

    /// Waits for every make under way.
    func waitForAll() async {
        for task in tasks.values {
            _ = await task.value
        }
    }

    // MARK: - Making

    private func make(_ display: ScreenshotDisplayType) async -> SimulatorMakeOutcome {
        guard let simulators else { return .nothingToMake(nil) }
        // The person's own install or make goes first.
        let deadline = ContinuousClock.now + busyLimit
        while simulators.working != nil {
            guard ContinuousClock.now < deadline, !Task.isCancelled else { return .busy }
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard case let .canMake(deviceType, _, runtime, _) = simulators.status(for: display) else {
            return .nothingToMake(simulators.status(for: display))
        }
        await simulators.make(for: display)
        if case let .ready(_, madeOn) = simulators.status(for: display) {
            failures[display] = nil
            return .made(runtime: madeOn)
        }
        let reason = simulators.failure ?? String(localized: "The \(deviceType) simulator couldn’t be made on \(runtime).")
        failures[display] = reason
        return .failed(reason)
    }
}
