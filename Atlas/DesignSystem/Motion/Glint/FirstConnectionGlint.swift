//
//  FirstConnectionGlint.swift
//  Atlas
//

import Foundation
import Observation

/// Effect 6 · First-time glint: once, just after an assistant first
/// connects, one soft purple sheen crosses the Autopilot button so people
/// find it. Never again on this Mac: the flag lives in `UserDefaults`, as
/// `@AppStorage` would keep it.
///
/// Whatever learns that an assistant connected for the first time calls
/// `FirstConnectionGlint.arm()`: the server on a paired client's first
/// request, the pairing sheet's Done, the Connect sheet as it closes. The
/// toolbar button (`AutopilotGlint`) plays it 0.8 s later and marks it
/// shown. Arming again does nothing.
@MainActor
@Observable
final class FirstConnectionGlint {
    static let shownKey = "motion.firstConnectionGlintShown"

    static let shared = FirstConnectionGlint(defaults: sharedDefaults)

    /// True from `arm()` until the button has played it.
    private(set) var isArmed = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// An assistant connected for the first time: the next Autopilot button
    /// on screen glints, unless it already did on this Mac.
    static func arm() {
        shared.arm()
    }

    /// True when this armed it.
    @discardableResult
    func arm() -> Bool {
        guard !hasShown, !isArmed else { return false }
        isArmed = true
        return true
    }

    /// The glint has played, or Reduce Motion skipped it: never again.
    func markShown() {
        isArmed = false
        defaults.set(true, forKey: Self.shownKey)
    }

    var hasShown: Bool {
        defaults.bool(forKey: Self.shownKey)
    }

    /// The unit test host keeps its flag away from the person's.
    private static var sharedDefaults: UserDefaults {
        #if DEBUG
        if UnitTestHost.isRunning, let defaults = UserDefaults(suiteName: "com.lima.atlas.unitTests.firstConnectionGlint") {
            return defaults
        }
        #endif
        return .standard
    }
}
