//
//  MotionToken.swift
//  Atlas
//

import SwiftUI

/// One motion token (README — Design system §7): how long and on which
/// curve. Views animate with its `animation`; the values are checked
/// against `design-tokens.json`.
struct MotionToken: Equatable, Sendable {
    /// Seconds; a spring's response.
    let duration: TimeInterval
    let curve: MotionCurve

    var animation: Animation {
        switch curve {
        case .easeOut:
            .easeOut(duration: duration)
        case let .bezier(x1, y1, x2, y2):
            .timingCurve(x1, y1, x2, y2, duration: duration)
        case let .spring(response, dampingFraction):
            .spring(response: response, dampingFraction: dampingFraction)
        }
    }

    /// The spring itself, for keyframes; nil for a curve.
    var spring: Spring? {
        guard case let .spring(response, dampingFraction) = curve else { return nil }
        return Spring(response: response, dampingRatio: dampingFraction)
    }

    /// `animation`, delayed.
    func delay(_ seconds: TimeInterval) -> Animation {
        animation.delay(seconds)
    }
}
