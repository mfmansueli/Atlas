//
//  AISparkBloom.swift
//  Atlas
//

import SwiftUI

/// Effect 3 · Arrived, on the chat's ✦ (README — Design system §7, v2, the
/// chat button): when the answer lands while the person looks, the ✦ signs
/// it with one bloom, a purple disc growing 0.6 → 1.9 as it fades
/// (motion.slow), and is still after. Only a fresh arrival blooms, once
/// (`ArrivalLedger`): the pill shown later, or redrawn, is still. With
/// Reduce Motion there's no bloom.
struct AISparkBloom: ViewModifier {
    /// What arrived; nil never blooms.
    let key: String?
    let arrivedAt: Date?
    var ledger: ArrivalLedger = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBlooming = false
    @State private var hasGrown = false

    nonisolated static let fromScale: CGFloat = 0.6
    nonisolated static let toScale: CGFloat = 1.9
    nonisolated static let startOpacity = 0.45

    func body(content: Content) -> some View {
        content
            .background {
                if isBlooming {
                    Circle()
                        .fill(Palette.aiFill)
                        .scaleEffect(hasGrown ? Self.toScale : Self.fromScale)
                        .opacity(hasGrown ? 0 : Self.startOpacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onAppear(perform: bloom)
    }

    private func bloom() {
        let claimed = key.flatMap { ledger.claim(key: $0, arrivedAt: arrivedAt) } != nil
        guard Self.blooms(claimed: claimed, reduceMotion: reduceMotion) else { return }
        isBlooming = true
        Task { @MainActor in
            await Task.yield()
            withAnimation(MotionTiming.slow.animation) {
                hasGrown = true
            } completion: {
                isBlooming = false
            }
        }
    }

    /// A fresh arrival blooms; never with Reduce Motion.
    nonisolated static func blooms(claimed: Bool, reduceMotion: Bool) -> Bool {
        claimed && !reduceMotion
    }
}

extension View {
    /// Effect 3 on the chat's ✦ when an answer lands; see `AISparkBloom`.
    func aiSparkBloom(key: String?, arrivedAt: Date?) -> some View {
        modifier(AISparkBloom(key: key, arrivedAt: arrivedAt))
    }
}
