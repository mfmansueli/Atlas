//
//  AIChatMotionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The chat button's motion (README — Design system §7, v2): the ✦
/// breathes and the step's text sweeps only while work runs, the bloom and
/// the tick only for a fresh arrival, and none of it with Reduce Motion.
@Suite("Motion v2 · the chat button")
struct AIChatMotionTests {
    @Test func theSparkBreathesOnlyWhileWorkRuns() {
        #expect(AIBreathing.breathes(true, reduceMotion: false))
        #expect(!AIBreathing.breathes(false, reduceMotion: false))
        #expect(!AIBreathing.breathes(true, reduceMotion: true))
        #expect(AIBreathing.Breath.exhaled.scale == 0.82)
        #expect(AIBreathing.Breath.inhaled.scale == 1.08)
        #expect(AIBreathing.Breath.exhaled.opacity == 0.55)
        #expect(AIBreathing.Breath.inhaled.opacity == 1)
    }

    @Test func theTextSweepsInTimeWithTheBar() {
        #expect(AITextSweep.sweeps(true, reduceMotion: false))
        #expect(!AITextSweep.sweeps(true, reduceMotion: true))
        #expect(!AITextSweep.sweeps(false, reduceMotion: false))
        // The bar's band from off the left (−1) to off the right (1.2).
        #expect(AITextSweep.position(of: -1) == 0)
        #expect(AITextSweep.position(of: 1.2) == 1)
        #expect(AITextSweep.position(of: 0.1) == 0.5)
        #expect(AITextSweep.position(of: 3) == 1)
    }

    @Test func theBloomAndTheTickPlayOnlyForAFreshArrival() {
        #expect(AISparkBloom.blooms(claimed: true, reduceMotion: false))
        #expect(!AISparkBloom.blooms(claimed: false, reduceMotion: false))
        #expect(!AISparkBloom.blooms(claimed: true, reduceMotion: true))
        #expect(AITickIn.ticks(claimed: true, reduceMotion: false))
        #expect(!AITickIn.ticks(claimed: false, reduceMotion: false))
        #expect(!AITickIn.ticks(claimed: true, reduceMotion: true))
        #expect(AISparkBloom.fromScale < 1 && AISparkBloom.toScale > 1)
        #expect(AITickIn.fromScale == 0.6)
    }

    @Test func aBreathIsTheTokensAndEachHalfIsHalfOfIt() {
        #expect(MotionTiming.breathe.duration == 1.5)
        #expect(MotionTiming.breathe.curve == .breathe)
    }
}
