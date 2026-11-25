//
//  MotionTiming+Sent.swift
//  Atlas
//

import Foundation

/// “Sent to Review & Push” (board 80, approved 25 November): Accept sends a
/// blue chip naming what was accepted from where the person clicked to
/// Review & Push at the bottom of the window, which pulses as it lands.
/// Blue, because it's what the person did, not what AI brought. Two
/// one-shots, each under 1.2 s: the flight (lift + arc, 0.72 s) and the
/// landing (pulse 0.5 s, ring 0.7 s). Reduce Motion: no flight and no
/// landing; only the count changes. The same values as
/// `design-tokens.json` → `motion.sent…`.
extension MotionTiming {
    /// 120 ms on the standard curve: the chip rises 10 pt from the click.
    static let sentLift = MotionToken(duration: 0.12, curve: .standard)
    /// 600 ms, the arc across: an ease-out (.25, .7, .35, 1)…
    static let sentFlyX = MotionToken(duration: 0.6, curve: .bezier(x1: 0.25, y1: 0.7, x2: 0.35, y2: 1))
    /// …and the arc down: an ease-in (.65, 0, .85, .55), so it curves.
    static let sentFlyY = MotionToken(duration: 0.6, curve: .bezier(x1: 0.65, y1: 0, x2: 0.85, y2: 0.55))
    /// Spring 0.5 / 0.5: Review & Push swells to 1.1 and back as it lands.
    static let sentLand = MotionToken(duration: 0.5, curve: .spring(response: 0.5, dampingFraction: 0.5))
    /// 700 ms, ease-out: the blue ring opening around it.
    static let sentRing = MotionToken(duration: 0.7, curve: .easeOut)

    /// From the click to the landing: the lift, then the arc.
    static var sentFlight: TimeInterval { sentLift.duration + sentFlyX.duration }
}
