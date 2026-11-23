//
//  TrailPath.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// Effect 1 · Trail (README — Design system §7, v2): the spark's way from
/// the button you asked with to the toolbar's Autopilot button, then down
/// to the place of the work, 0.7 s per leg on motion.base. Up first, then
/// across, on the way to the toolbar; across first, then down, on the way
/// to the place. Asked from the toolbar itself there's only the way down.
/// It fades only as it lands, where the place's own still spark takes over.
struct TrailPath: Equatable {
    let from: CGPoint
    /// The Autopilot button.
    let via: CGPoint
    /// Where the work happens; nil ends the trail on the toolbar.
    let place: CGPoint?

    init(from: CGPoint, via: CGPoint, to place: CGPoint?) {
        self.from = from
        self.via = via
        self.place = place
    }

    /// After the click, before the spark moves.
    static let delay: TimeInterval = 0.04
    static let leg = MotionTiming.trailLeg
    /// The last moment of the last leg, when the spark fades into the place.
    static let fade: TimeInterval = 0.15
    /// The spark's size, in points.
    static let size: CGFloat = 18

    /// Seconds after the click when the spark reaches the toolbar, and the
    /// Autopilot button starts working.
    static let toolbarLanding = delay + leg

    struct State: Equatable {
        var center: CGPoint
        var opacity: Double
    }

    /// How many legs: two from a button in the page, one from the toolbar.
    var legs: Int {
        place == nil || from == via ? 1 : 2
    }

    /// The whole trail, after `delay`.
    var duration: TimeInterval {
        Double(legs) * Self.leg
    }

    /// Where the spark is `elapsed` seconds into the trail (after `delay`).
    func state(at elapsed: TimeInterval) -> State {
        let time = min(max(elapsed, 0), duration)
        let center: CGPoint = if from == via, let place {
            // From the toolbar: only down to the place.
            Self.point(from: via, to: place, risesFirst: false, at: time / Self.leg)
        } else if time <= Self.leg || place == nil {
            Self.point(from: from, to: via, risesFirst: true, at: time / Self.leg)
        } else {
            Self.point(from: via, to: place ?? via, risesFirst: false, at: (time - Self.leg) / Self.leg)
        }
        let fadeStart = duration - Self.fade
        let opacity = time < fadeStart ? 1 : max(0, 1 - (time - fadeStart) / Self.fade)
        return State(center: center, opacity: opacity)
    }

    /// A quadratic arc from `start` to `end`, `linear` of the way along it
    /// on motion.base: rising first (its corner above the start) or
    /// crossing first (its corner beside the start).
    static func point(from start: CGPoint, to end: CGPoint, risesFirst: Bool, at linear: Double) -> CGPoint {
        let progress = MotionCurve.standard.unitCurve.value(at: min(max(linear, 0), 1))
        let corner = risesFirst ? CGPoint(x: start.x, y: end.y) : CGPoint(x: end.x, y: start.y)
        let rest = 1 - progress
        return CGPoint(
            x: rest * rest * start.x + 2 * rest * progress * corner.x + progress * progress * end.x,
            y: rest * rest * start.y + 2 * rest * progress * corner.y + progress * progress * end.y
        )
    }
}
