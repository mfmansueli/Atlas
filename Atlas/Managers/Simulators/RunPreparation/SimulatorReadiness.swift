//
//  SimulatorReadiness.swift
//  Atlas
//

import Foundation

/// A device's simulator as `get_capture_plan` says it (`devices[].simulator`):
/// there, being made by Atlas, or waiting on something only the person
/// can install.
enum SimulatorReadiness: String, Hashable, Sendable {
    case ready
    /// Atlas is making it, or makes it before the device's captures: only
    /// the simulator was missing.
    case making
    /// This Mac lacks the runtime that runs it (or an Xcode that knows the
    /// device): the person installs it, so it's reported once with
    /// affectsDevice.
    case needsRuntime
    /// Atlas tried to make it and `create-simulator` failed: its problem,
    /// with what it said, waits for the person already.
    case couldntMake

    /// `status` as the assistant needs it, for `maker`'s device `display`.
    /// Nil when it isn't known.
    @MainActor
    init?(_ status: SimulatorStatus?, display: ScreenshotDisplayType, maker: SimulatorMaker) {
        let failed = maker.failures[display] != nil
        self.init(status, isMaking: maker.isMaking(display), failed: failed)
    }

    /// `isMaking` while the make is under way; `failed` when the last one
    /// didn't work.
    init?(_ status: SimulatorStatus?, isMaking: Bool = false, failed: Bool = false) {
        if isMaking {
            self = .making
            return
        }
        switch status {
        case .ready: self = .ready
        case .canMake: self = failed ? .couldntMake : .making
        case .needsRuntime, .needsNewerXcode: self = .needsRuntime
        case nil: return nil
        }
    }
}
