//
//  UnitBezierTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("UnitBezier")
struct UnitBezierTests {
    private let ease = UnitBezier(x1: 0.45, y1: 0, x2: 0.25, y2: 1)

    @Test func startsAndEndsInPlace() {
        #expect(ease.value(at: 0) == 0)
        #expect(ease.value(at: 1) == 1)
        #expect(ease.value(at: -1) == 0)
        #expect(ease.value(at: 2) == 1)
    }

    @Test func linearIsTheIdentity() {
        let linear = UnitBezier(x1: 0, y1: 0, x2: 1, y2: 1)
        for x in stride(from: 0.05, to: 1, by: 0.1) {
            #expect(abs(linear.value(at: x) - x) < 1e-6)
        }
    }

    @Test func easesInSlowlyAndRisesSteadily() {
        #expect(ease.value(at: 0.1) < 0.05)
        var previous = 0.0
        for x in stride(from: 0.02, through: 1, by: 0.02) {
            let value = ease.value(at: x)
            #expect(value >= previous)
            previous = value
        }
    }

    @Test func matchesCSSEaseInOut() {
        // cubic-bezier(.42, 0, .58, 1) is symmetric: half way is half way.
        let easeInOut = UnitBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)
        #expect(abs(easeInOut.value(at: 0.5) - 0.5) < 1e-6)
        #expect(abs(easeInOut.value(at: 0.25) + easeInOut.value(at: 0.75) - 1) < 1e-6)
    }
}
