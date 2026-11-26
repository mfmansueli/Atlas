//
//  AutopilotBarOpeningTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The bar grows up in 0.34 s on the standard curve, what's inside 0.1 s
/// later, and shrinks back in 0.24 s; with Reduce Motion it swaps at once
/// (board 80, Motion v2: no one-shot over 1.2 s).
@Suite("Autopilot bar · opening")
struct AutopilotBarOpeningTests {
    @Test func itGrowsAndShrinksOnTheMotionTokens() {
        let grow = AutopilotBarOpening.style(reduceMotion: false)
        #expect(grow == .grow)
        #expect(grow.token(opening: true) == MotionTiming.open)
        #expect(grow.token(opening: false) == MotionTiming.close)
        #expect(MotionTiming.open.duration == 0.34)
        #expect(MotionTiming.close.duration == 0.24)
        #expect(MotionTiming.openContentDelay == 0.1)
        #expect(MotionTiming.open.curve == .standard)
    }

    @Test func reduceMotionSwapsAtOnce() {
        let swap = AutopilotBarOpening.style(reduceMotion: true)
        #expect(swap == .swap)
        #expect(swap.token(opening: true) == nil)
        #expect(swap.animation(opening: false) == nil)
    }

    @Test func noOneShotIsLongerThanMotionAllows() {
        #expect(MotionTiming.open.duration + MotionTiming.openContentDelay + MotionTiming.base.duration <= 1.2)
    }
}
