//
//  AIBreathing.swift
//  Atlas
//

import SwiftUI

/// Effect 2 · Working, on the chat's ✦ (README — Design system §7, v2, the
/// chat button): while the question is sent and the answer worked on, the
/// sparkles breathe, like `.symbolEffect(.breathe)`: 0.82 → 1.08 in scale,
/// 0.55 → 1 in opacity, one breath every 1.5 s (motion.breathe). It belongs
/// to the one loop on screen, with the step's sweep; it stops as soon as
/// the work does. With Reduce Motion the ✦ is still.
struct AIBreathing: ViewModifier {
    let isBreathing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The two ends of a breath.
    enum Breath: CaseIterable {
        case exhaled
        case inhaled

        var scale: CGFloat {
            switch self {
            case .exhaled: AIBreathing.smallest
            case .inhaled: AIBreathing.largest
            }
        }

        var opacity: Double {
            switch self {
            case .exhaled: AIBreathing.faintest
            case .inhaled: 1
            }
        }
    }

    nonisolated static let smallest: CGFloat = 0.82
    nonisolated static let largest: CGFloat = 1.08
    nonisolated static let faintest = 0.55

    func body(content: Content) -> some View {
        if Self.breathes(isBreathing, reduceMotion: reduceMotion) {
            content.phaseAnimator(Breath.allCases) { view, breath in
                view.scaleEffect(breath.scale).opacity(breath.opacity)
            } animation: { _ in
                // Each end of the breath is half of it.
                MotionTiming.breathe.animation(lasting: MotionTiming.breathe.duration / 2)
            }
        } else {
            content
        }
    }

    /// Only work that runs breathes, and never with Reduce Motion.
    nonisolated static func breathes(_ isBreathing: Bool, reduceMotion: Bool) -> Bool {
        isBreathing && !reduceMotion
    }
}

extension View {
    /// Effect 2 on the chat's ✦ while it works; see `AIBreathing`.
    func aiBreathing(_ isBreathing: Bool) -> some View {
        modifier(AIBreathing(isBreathing: isBreathing))
    }
}
