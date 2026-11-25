//
//  AutopilotBarOpening.swift
//  Atlas
//

import SwiftUI

/// How the Autopilot bar opens and closes (board 80): it grows up from its
/// field in 0.34 s (motion.open) and what's inside comes in 0.1 s later;
/// closing, it shrinks back to its field in 0.24 s (motion.close). With
/// Reduce Motion the two swap at once. The bar is anchored at its bottom,
/// so the page under it never moves.
enum AutopilotBarOpening: Equatable {
    case grow
    /// Reduce Motion: a direct swap.
    case swap

    nonisolated static func style(reduceMotion: Bool) -> Self {
        reduceMotion ? .swap : .grow
    }

    /// The bar's own height change, opening or closing; nil swaps.
    func token(opening: Bool) -> MotionToken? {
        switch self {
        case .grow: opening ? MotionTiming.open : MotionTiming.close
        case .swap: nil
        }
    }

    func animation(opening: Bool) -> Animation? {
        token(opening: opening)?.animation
    }

    /// What's inside the open bar comes in after it starts to grow, 8 pt
    /// up, and leaves at once.
    var contentTransition: AnyTransition {
        switch self {
        case .grow:
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: Spacing.small))
                    .animation(MotionTiming.base.delay(MotionTiming.openContentDelay)),
                removal: .opacity.animation(MotionTiming.fast.animation)
            )
        case .swap:
            .identity
        }
    }
}
