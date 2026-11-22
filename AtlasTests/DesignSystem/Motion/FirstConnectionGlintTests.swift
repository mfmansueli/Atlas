//
//  FirstConnectionGlintTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Effect 6 · First-time glint: once, after an assistant first connects,
/// and never again on this Mac.
@MainActor
@Suite("FirstConnectionGlint")
struct FirstConnectionGlintTests {
    private func defaults() throws -> UserDefaults {
        let name = "FirstConnectionGlintTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func armingPlaysOnceThenNeverAgain() throws {
        let defaults = try defaults()
        let glint = FirstConnectionGlint(defaults: defaults)
        #expect(!glint.isArmed)
        #expect(!glint.hasShown)

        #expect(glint.arm())
        #expect(glint.isArmed)
        // Another connection before it played: still one glint.
        #expect(!glint.arm())

        glint.markShown()
        #expect(!glint.isArmed)
        #expect(glint.hasShown)
        #expect(!glint.arm())
        #expect(!glint.isArmed)
    }

    @Test func theFlagIsPerMacNotPerLaunch() throws {
        let defaults = try defaults()
        FirstConnectionGlint(defaults: defaults).markShown()
        let nextLaunch = FirstConnectionGlint(defaults: defaults)
        #expect(nextLaunch.hasShown)
        #expect(!nextLaunch.arm())
        #expect(defaults.bool(forKey: FirstConnectionGlint.shownKey))
    }

    @Test func theSheenSweepsFromBeforeTheButtonToPastIt() {
        #expect(AutopilotGlint.bandPosition(elapsed: 0) == -0.5)
        #expect(AutopilotGlint.bandPosition(elapsed: -1) == -0.5)
        #expect(abs(AutopilotGlint.bandPosition(elapsed: MotionTiming.glintDuration) - 1.2) < 0.000_1)
        #expect(abs(AutopilotGlint.bandPosition(elapsed: 10) - 1.2) < 0.000_1)
        let half = AutopilotGlint.bandPosition(elapsed: MotionTiming.glintDuration / 2)
        #expect(half > 0.3 && half < 0.4)
    }
}
