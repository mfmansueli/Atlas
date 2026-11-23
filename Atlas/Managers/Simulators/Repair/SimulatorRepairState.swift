//
//  SimulatorRepairState.swift
//  Atlas
//

import Foundation

/// Where Atlas's own repair of this Mac's simulators stands
/// (`SimulatorRepair`).
enum SimulatorRepairState: Hashable, Sendable {
    case idle
    /// Shutting the simulators down and restarting their service.
    case restartingSimulators
    /// Restarting the Mac's audio service: macOS is asking for an
    /// administrator's password.
    case restartingAudio
    /// Starting a simulator to see whether the repair worked.
    case checking
    /// A simulator starts again.
    case repaired
    /// The person closed macOS's password request.
    case declined
    /// The saved helper is from before it could repair, or isn't saved.
    case needsHelper
    /// It still doesn't start: what `simctl` said.
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .restartingSimulators, .restartingAudio, .checking: true
        case .idle, .repaired, .declined, .needsHelper, .failed: false
        }
    }

    /// What the problem's card says under the fault, nil while idle.
    var message: String? {
        switch self {
        case .idle: nil
        case .restartingSimulators: String(localized: "Restarting this Mac’s simulators…")
        case .restartingAudio:
            String(localized: "Restarting this Mac’s audio service. macOS asks for your password.")
        case .checking: String(localized: "Checking that a simulator starts…")
        case .repaired: String(localized: "Simulators work again. The run continues.")
        case .declined:
            String(localized: "Password request closed: audio service not restarted. Fix It asks again, or restart the Mac.")
        case .needsHelper:
            String(localized: "The saved helper is too old to repair this. Save it again to start the repair.")
        case let .failed(reason):
            String(localized: "Simulators still won’t start: \(reason) Restarting the Mac usually fixes it.")
        }
    }
}
