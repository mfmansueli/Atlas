//
//  MotionTiming.swift
//  Atlas
//

import SwiftUI

/// The curves and times of the assistant's motion (README Design system
/// §7): rare, short and once. Springs, not bounces: about 0.35 s with
/// damping 0.8 for layout, 0.6 only for the count tick. Purple light for AI;
/// blue never animates.
enum MotionTiming {
    /// Layout: a card's height closing, rows moving up after it.
    static let layoutSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// The count tick's spring, 0.45 s with damping 0.6.
    static let tickSpring = Spring(response: 0.45, dampingRatio: 0.6)
    /// How far a badge swells when its count goes up.
    static let tickScale: CGFloat = 1.18

    /// Arrival: the tint fades in.
    static let arrivalTint = Animation.easeOut(duration: 0.4)
    /// Arrival: one light pass round the edge, ease-out.
    static let arrivalPassDuration: TimeInterval = 1.1

    /// Accept: the purple tint goes.
    static let acceptTint = Animation.easeOut(duration: 0.25)
    /// Accept: the check draws, a moment after the tint starts to go.
    static let acceptCheck = Animation.easeOut(duration: 0.3).delay(0.05)
    /// Accept: the card closes once the check has drawn.
    static let acceptCommitDelay: Duration = .milliseconds(400)

    /// Reduce Motion's stand-in for a settle: a short cross-fade.
    static let reducedCrossFade = Animation.easeInOut(duration: 0.15)

    /// First-time glint: how long after the connection, then one sweep.
    static let glintDelay: Duration = .milliseconds(800)
    static let glintDuration: TimeInterval = 1.2
}
