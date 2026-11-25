//
//  PushFlightPath.swift
//  Atlas
//

import CoreGraphics
import Foundation
import SwiftUI

/// Where the chip is at each moment of its flight (board 80), in a space
/// whose y grows downward: first it rises 10 pt from the click and swells
/// a little (`MotionTiming.sentLift`, 0.12 s); then it arcs to Review &
/// Push in 0.6 s, across on an ease-out and down on an ease-in
/// (`sentFlyX`, `sentFlyY`), shrinking to half and fading a little.
struct PushFlightPath: Equatable, Sendable {
    static let liftDistance: CGFloat = 10
    static let liftScale: CGFloat = 1.06
    static let landingScale: CGFloat = 0.5
    static let landingOpacity = 0.6

    let start: CGPoint
    let target: CGPoint

    /// The chip at one moment.
    struct Frame: Equatable, Sendable {
        var point: CGPoint
        var scale: CGFloat
        var opacity: Double
    }

    /// Lift and arc together.
    static var duration: TimeInterval { MotionTiming.sentFlight }

    /// The chip `elapsed` seconds after the click; on the target from the
    /// end of the flight on.
    func frame(at elapsed: TimeInterval) -> Frame {
        let lift = MotionTiming.sentLift.duration
        let lifted = CGPoint(x: start.x, y: start.y - Self.liftDistance)
        if elapsed < lift {
            let progress = Self.progress(MotionTiming.sentLift, max(0, elapsed) / lift)
            return Frame(
                point: CGPoint(x: start.x, y: start.y - Self.liftDistance * progress),
                scale: 1 + (Self.liftScale - 1) * progress,
                opacity: 1
            )
        }
        let fly = min(1, (elapsed - lift) / MotionTiming.sentFlyX.duration)
        let across = Self.progress(MotionTiming.sentFlyX, fly)
        let down = Self.progress(MotionTiming.sentFlyY, fly)
        return Frame(
            point: CGPoint(x: lifted.x + (target.x - lifted.x) * across, y: lifted.y + (target.y - lifted.y) * down),
            scale: Self.liftScale + (Self.landingScale - Self.liftScale) * down,
            opacity: 1 + (Self.landingOpacity - 1) * down
        )
    }

    /// The token's curve at `fraction` of its time.
    private static func progress(_ token: MotionToken, _ fraction: Double) -> CGFloat {
        CGFloat(token.curve.unitCurve.value(at: min(1, max(0, fraction))))
    }
}
