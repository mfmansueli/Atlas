//
//  AIDecidedTests.swift
//  AtlasTests
//

import Foundation
import SwiftUI
import Testing
@testable import Atlas

/// Effect 4 · Accepted · Dismissed · Undone: accept goes neutral and draws
/// its check, then is made; dismiss and undo are made at once in the layout
/// spring; with Reduce Motion everything is a direct swap in a fade.
@MainActor
@Suite("AIDecided")
struct AIDecidedTests {
    @Test func theAcceptIsMadeOnceTheCheckHasDrawn() {
        #expect(AIDecided.commitDelay(reduceMotion: false) == .milliseconds(400))
        #expect(AIDecided.commitDelay(reduceMotion: true) == .zero)
        #expect(AIDecided.commitAnimation(reduceMotion: false) == MotionTiming.layout.animation)
        #expect(AIDecided.commitAnimation(reduceMotion: true) == MotionTiming.fast.animation)
        #expect(AIDecided.undoSlide == 6)
    }

    @Test func withReduceMotionTheAcceptIsMadeAtOnce() {
        let steps = Steps()
        AIDecided.accept(reduceMotion: true) {
            steps.names.append("settle")
        } commit: {
            steps.names.append("commit")
        }
        #expect(steps.names == ["settle", "commit"])
    }

    @Test func otherwiseItSettlesFirstAndIsMadeAfterTheCheck() async {
        let steps = Steps()
        AIDecided.accept(reduceMotion: false) {
            steps.names.append("settle")
        } commit: {
            steps.names.append("commit")
        }
        // Settled right away, not made yet.
        #expect(steps.names == ["settle"])
        try? await Task.sleep(for: .milliseconds(150))
        #expect(steps.names == ["settle"])
        try? await Task.sleep(for: .milliseconds(900))
        #expect(steps.names == ["settle", "commit"])
    }

    @Test func dismissAndUndoAreMadeAtOnce() {
        let steps = Steps()
        AIDecided.dismiss(reduceMotion: false) { steps.names.append("dismiss") }
        AIDecided.undo(reduceMotion: true) { steps.names.append("undo") }
        #expect(steps.names == ["dismiss", "undo"])
    }

    @MainActor
    private final class Steps {
        var names: [String] = []
    }
}
