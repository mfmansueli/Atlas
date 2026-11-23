//
//  AIWorking.swift
//  Atlas
//

import SwiftUI

/// Effect 2 · Working, on the item being worked on (README — Design system
/// §7, v2): the spark that travelled there (`aiTrail`) sits still on it
/// while the work really runs: no ring, no light, no pulse. When the work
/// ends the spark signs the result with one bloom (scale 1 → 1.5, fading,
/// motion.slow) and is gone. With Reduce Motion the spark is still and
/// goes without the bloom.
struct AIWorking: ViewModifier {
    let isWorking: Bool
    var alignment: Alignment = .topTrailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlooming = false
    @State private var hasBloomed = false

    /// How far the spark grows as it signs.
    static let bloomScale: CGFloat = 1.5

    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                if isWorking || isBlooming {
                    AISpark()
                        .scaleEffect(hasBloomed ? Self.bloomScale : 1)
                        .opacity(hasBloomed ? 0 : 1)
                        .padding(Spacing.small)
                        .transition(.identity)
                }
            }
            .onChange(of: isWorking) { wasWorking, working in
                guard wasWorking, !working, !reduceMotion else { return }
                isBlooming = true
                withAnimation(MotionTiming.slow.animation) { hasBloomed = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(MotionTiming.slow.duration))
                    isBlooming = false
                    hasBloomed = false
                }
            }
    }
}

extension View {
    /// Effect 2 on the item being worked on; see `AIWorking`.
    func aiWorking(_ isWorking: Bool, alignment: Alignment = .topTrailing) -> some View {
        modifier(AIWorking(isWorking: isWorking, alignment: alignment))
    }
}
