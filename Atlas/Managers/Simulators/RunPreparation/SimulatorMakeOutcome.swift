//
//  SimulatorMakeOutcome.swift
//  Atlas
//

import Foundation

/// How Atlas making a device's simulator on its own ended
/// (`SimulatorMaker`).
enum SimulatorMakeOutcome: Hashable, Sendable {
    /// Made, on this runtime: "iOS 27.2".
    case made(runtime: String)
    /// `create-simulator` failed: what it said.
    case failed(String)
    /// Nothing to make: one is there already, or what's missing is more than
    /// a simulator (a runtime to download, a newer Xcode, the helper). The
    /// status then, nil when it isn't known.
    case nothingToMake(SimulatorStatus?)
    /// The person's own install or make kept the helper busy.
    case busy
}
