//
//  MotionTiming.swift
//  Atlas
//

import SwiftUI

/// The motion tokens (README — Design system §7, motion v2, “the spark”),
/// the same values as `design-tokens.json`. Motion belongs to the
/// assistant: five effects (`aiTrail`, `aiWorking`, `aiArrived`,
/// `aiDecided`, `aiNeedsYou`), gently and once. At most one loop on screen
/// (the progress sweep), only while work really runs; no one-shot effect
/// longer than 1.2 s; nothing moves on opening a screen; blue never
/// animates. Each effect reads Reduce Motion itself.
enum MotionTiming {
    /// 150 ms, ease-out: Reduce Motion's cross-fades, small swaps.
    static let fast = MotionToken(duration: 0.15, curve: .easeOut)
    /// 250 ms on (.2, .7, .2, 1): an accepted suggestion's tint, a
    /// failure sliding in, each leg of the Trail's spark at 0.7 s.
    static let base = MotionToken(duration: 0.25, curve: .standard)
    /// 400 ms, same curve: an arrival's tint, the spark's bloom.
    static let slow = MotionToken(duration: 0.4, curve: .standard)
    /// 500 ms, ease-in-out: one step of a progress bar.
    static let step = MotionToken(duration: 0.5, curve: .step)
    /// Spring 0.35 / 0.8: a card closing, rows moving up after it.
    static let layout = MotionToken(duration: 0.35, curve: .spring(response: 0.35, dampingFraction: 0.8))
    /// Spring 0.45 / 0.6: the count tick and the Needs-you nudge, the only
    /// springs that bounce a little.
    static let tick = MotionToken(duration: 0.45, curve: .spring(response: 0.45, dampingFraction: 0.6))

    /// 70 ms between the items of a list that arrive together…
    static let staggerDelay: TimeInterval = 0.07
    /// …and at most this many of them move; the rest appear still.
    static let staggerLimit = 6
    /// The progress bar's soft sweep: one pass and its pause.
    static let sweep: TimeInterval = 2.8

    /// How long one leg of the Trail takes: button → Autopilot, Autopilot
    /// → the place of the work.
    static let trailLeg: TimeInterval = 0.7

    /// When item `index` of a burst of arrivals starts; nil once the
    /// burst has used its six, so it appears still.
    static func staggerDelay(for index: Int) -> TimeInterval? {
        guard index >= 0, index < staggerLimit else { return nil }
        return Double(index) * staggerDelay
    }
}
