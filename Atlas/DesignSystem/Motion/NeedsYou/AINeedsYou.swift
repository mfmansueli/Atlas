//
//  AINeedsYou.swift
//  Atlas
//

import SwiftUI

/// Effect 5 · Needs you (README — Design system §7, v2): when the assistant
/// waits for the person, the Autopilot button fills with aiFill and says
/// what it needs; as it starts waiting it nudges once, 1 → 1.06 → 1 on a
/// spring (0.45 s), then stays still. Nothing pulses. With Reduce Motion
/// only the colour changes. Already waiting when it appears (the window
/// opened on it), it doesn't nudge.
struct AINeedsYou: ViewModifier {
    let isNeedingYou: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nudges = 0

    /// How far the nudge swells.
    static let scale: CGFloat = 1.06

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat(1), trigger: nudges) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(Self.scale, duration: 0.2, spring: Self.spring)
                SpringKeyframe(1, duration: 0.25, spring: Self.spring)
            }
            .onChange(of: isNeedingYou) { wasNeeding, needing in
                if Self.nudges(from: wasNeeding, to: needing, reduceMotion: reduceMotion) { nudges += 1 }
            }
    }

    static let spring = MotionTiming.tick.spring ?? Spring()

    /// Only starting to wait nudges; going on waiting or stopping is still.
    nonisolated static func nudges(from wasNeeding: Bool, to needing: Bool, reduceMotion: Bool) -> Bool {
        !wasNeeding && needing && !reduceMotion
    }
}

extension View {
    /// Effect 5 on the Autopilot button; see `AINeedsYou`.
    func aiNeedsYou(_ isNeedingYou: Bool) -> some View {
        modifier(AINeedsYou(isNeedingYou: isNeedingYou))
    }
}
