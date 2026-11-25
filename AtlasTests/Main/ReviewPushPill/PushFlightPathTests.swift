//
//  PushFlightPathTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The chip rises 10 pt in 0.12 s, then arcs to the pill in 0.6 s, across
/// on an ease-out and down on an ease-in, shrinking to half.
@Suite("PushFlightPath")
struct PushFlightPathTests {
    private let path = PushFlightPath(start: CGPoint(x: 100, y: 400), target: CGPoint(x: 900, y: 700))

    @Test func itStartsAtTheClick() {
        let frame = path.frame(at: 0)
        #expect(frame.point == CGPoint(x: 100, y: 400))
        #expect(frame.scale == 1)
        #expect(frame.opacity == 1)
    }

    @Test func itRisesTenPointsFirst() {
        let frame = path.frame(at: MotionTiming.sentLift.duration - 0.000_1)
        #expect(abs(frame.point.y - 390) < 0.1)
        #expect(frame.point.x == 100)
        #expect(frame.scale > 1)
    }

    @Test func itLandsOnThePillAtHalfItsSize() {
        let frame = path.frame(at: PushFlightPath.duration)
        #expect(abs(frame.point.x - 900) < 0.001)
        #expect(abs(frame.point.y - 700) < 0.001)
        #expect(abs(frame.scale - PushFlightPath.landingScale) < 0.001)
        #expect(abs(frame.opacity - PushFlightPath.landingOpacity) < 0.001)
        #expect(path.frame(at: 5) == frame, "It stays on the pill after")
    }

    /// Across faster than down: an arc, not a line.
    @Test func midwayItIsFurtherAcrossThanDown() {
        let frame = path.frame(at: MotionTiming.sentLift.duration + MotionTiming.sentFlyX.duration / 2)
        let across = (frame.point.x - 100) / 800
        let down = (frame.point.y - 390) / 310
        #expect(across > 0.5)
        #expect(down < 0.5)
        #expect(across > down)
    }

    /// README-DS §7: no one-shot over 1.2 s. The flight and the landing
    /// are one each.
    @Test func eachOneShotStaysUnderOnePointTwoSeconds() {
        #expect(abs(PushFlightPath.duration - 0.72) < 0.000_1)
        #expect(PushFlightPath.duration <= 1.2)
        #expect(MotionTiming.sentLand.duration <= 1.2)
        #expect(MotionTiming.sentRing.duration <= 1.2)
    }
}
