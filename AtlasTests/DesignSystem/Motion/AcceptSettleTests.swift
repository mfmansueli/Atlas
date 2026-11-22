//
//  AcceptSettleTests.swift
//  AtlasTests
//

import Foundation
import SwiftUI
import Testing
@testable import Atlas

/// Effect 5 · Accept settles: the tint goes and the check draws, then the
/// accept is committed in the closing spring; with Reduce Motion it's
/// committed at once in a cross-fade.
@MainActor
@Suite("AcceptSettle")
struct AcceptSettleTests {
    @Test func theCardClosesOnceTheCheckHasDrawn() {
        #expect(AcceptSettle.commitDelay(reduceMotion: false) == .milliseconds(400))
        #expect(AcceptSettle.commitDelay(reduceMotion: true) == .zero)
        #expect(AcceptSettle.commitAnimation(reduceMotion: false) == MotionTiming.layoutSpring)
        #expect(AcceptSettle.commitAnimation(reduceMotion: true) == MotionTiming.reducedCrossFade)
    }

    @Test func withReduceMotionTheAcceptIsCommittedAtOnce() {
        let steps = Steps()
        AcceptSettle.perform(reduceMotion: true) {
            steps.names.append("settle")
        } commit: {
            steps.names.append("commit")
        }
        #expect(steps.names == ["settle", "commit"])
    }

    @Test func otherwiseItSettlesFirstAndCommitsAfterTheCheck() async {
        let steps = Steps()
        AcceptSettle.perform(reduceMotion: false) {
            steps.names.append("settle")
        } commit: {
            steps.names.append("commit")
        }
        // Settled right away, not committed yet.
        #expect(steps.names == ["settle"])
        try? await Task.sleep(for: .milliseconds(150))
        #expect(steps.names == ["settle"])
        try? await Task.sleep(for: .milliseconds(900))
        #expect(steps.names == ["settle", "commit"])
    }

    @MainActor
    private final class Steps {
        var names: [String] = []
    }
}
