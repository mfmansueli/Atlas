//
//  CountTick.swift
//  Atlas
//

import SwiftUI

/// Effect 4 · Count tick: when a badge goes up because new suggestions
/// came, the number rolls (`.numericText`) and the badge swells 1 → 1.18 → 1
/// on a 0.45 s spring. Going down: the number just changes. With Reduce
/// Motion the number changes, no roll and no scale. `CountTickPolicy` says
/// when it's news.
///
/// Put it on a view that stays while the count is zero (the badge's own
/// view, not its `if`), so the first suggestion ticks too.
struct CountTick: ViewModifier {
    let count: Int
    /// What the count is of (the app): a new one is a new baseline.
    var scope: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var policy: CountTickPolicy
    @State private var ticks = 0

    init(count: Int, scope: String? = nil) {
        self.count = count
        self.scope = scope
        _policy = State(initialValue: CountTickPolicy(count: count, scope: scope))
    }

    func body(content: Content) -> some View {
        let rolls = !reduceMotion && policy.wouldTick(count: count, scope: scope)
        content
            .contentTransition(rolls ? .numericText(value: Double(count)) : .identity)
            .transaction(value: count) { transaction in
                // Only news moves; a count going down or loading is still.
                transaction.animation = rolls ? .spring(MotionTiming.tickSpring) : nil
            }
            .keyframeAnimator(initialValue: CGFloat(1), trigger: ticks) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(MotionTiming.tickScale, duration: 0.16, spring: MotionTiming.tickSpring)
                SpringKeyframe(1, duration: 0.29, spring: MotionTiming.tickSpring)
            }
            .onChange(of: Input(count: count, scope: scope)) { _, input in
                if policy.update(count: input.count, scope: input.scope), !reduceMotion {
                    ticks += 1
                }
            }
    }

    private struct Input: Equatable {
        var count: Int
        var scope: String?
    }
}
