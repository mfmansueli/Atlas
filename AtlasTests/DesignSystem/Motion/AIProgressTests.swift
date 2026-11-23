//
//  AIProgressTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Effect 2 · Working, counted: real units, “2 of 3” up to about 20, then
/// “38% · 97 of 255”; time left only after a few units, from their
/// average; a stepped bar whose sweep crosses, then pauses.
@Suite("AIProgress")
struct AIProgressTests {
    @Test func fewUnitsCount() {
        #expect(AIProgress(done: 2, total: 3).label == "2 of 3")
        #expect(AIProgress(done: 20, total: 20).label == "20 of 20")
        #expect(AIProgress(done: 0, total: 1).label == "0 of 1")
    }

    @Test func manyUnitsAddAPercentage() {
        #expect(AIProgress(done: 97, total: 255).label == "38% · 97 of 255")
        #expect(AIProgress(done: 0, total: 21).label == "0% · 0 of 21")
        #expect(AIProgress(done: 255, total: 255).label == "100% · 255 of 255")
    }

    @Test func unitsStayInsideTheTotal() {
        let over = AIProgress(done: 9, total: 4)
        #expect(over.done == 4)
        #expect(over.fraction == 1)
        let under = AIProgress(done: -2, total: 4)
        #expect(under.done == 0)
        #expect(AIProgress(done: 0, total: 0).fraction == 0)
    }

    @Test func timeLeftWaitsForAFewUnitsAndUsesTheirAverage() {
        // Two done: too early to say.
        #expect(AIProgress(done: 2, total: 10).secondsLeft(elapsed: 60) == nil)
        #expect(AIProgress(done: 2, total: 10).timeLeft(elapsed: 60) == nil)
        // Three in 90 s: 30 s each, seven left.
        #expect(AIProgress(done: 3, total: 10).secondsLeft(elapsed: 90) == 210)
        #expect(AIProgress(done: 3, total: 10).timeLeft(elapsed: 90) == "about 4 min left")
        #expect(AIProgress(done: 3, total: 10).line(elapsed: 90) == "3 of 10 · about 4 min left")
        // Done: nothing left to wait for.
        #expect(AIProgress(done: 10, total: 10).timeLeft(elapsed: 90) == nil)
        #expect(AIProgress(done: 100, total: 255).timeLeft(elapsed: 3000) == "about 1 h 18 min left")
        #expect(AIProgress(done: 3, total: 4).timeLeft(elapsed: 3) == "about 1 min left")
    }

    @Test func theSweepCrossesThenPauses() {
        let start = AIProgressBar.sweep(at: 0)
        #expect(start.offset == -1)
        #expect(start.opacity == 0)
        let middle = AIProgressBar.sweep(at: MotionTiming.sweep * 0.37)
        #expect(middle.opacity == 1)
        #expect(abs(middle.offset - 0.1) < 0.01)
        // The pause: gone, waiting past the end.
        let pause = AIProgressBar.sweep(at: MotionTiming.sweep * 0.9)
        #expect(pause == (1.2, 0))
        // One pass every 2.8 s.
        #expect(AIProgressBar.sweep(at: MotionTiming.sweep).offset == -1)
    }
}
