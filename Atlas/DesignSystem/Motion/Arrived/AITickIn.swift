//
//  AITickIn.swift
//  Atlas
//

import SwiftUI

/// Effect 3 · Arrived, on a pill that comes with what arrived (README —
/// Design system §7, v2, the chat button: “1 suggestion”, “Answer”, “Needs
/// you”): it ticks in once, 0.6 → 1 as it fades in, on motion.tick
/// (spring 0.45 / 0.6). Only a fresh arrival ticks, once
/// (`ArrivalLedger`): a pill already there when the screen opened is
/// still. With Reduce Motion it appears at once.
///
/// Put it on the pill inside its `if`, so it's made when the pill comes.
struct AITickIn: ViewModifier {
    /// What arrived; nil never ticks.
    let key: String?
    let arrivedAt: Date?
    var ledger: ArrivalLedger = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown: Bool

    nonisolated static let fromScale: CGFloat = 0.6

    init(key: String?, arrivedAt: Date?, ledger: ArrivalLedger = .shared) {
        self.key = key
        self.arrivedAt = arrivedAt
        self.ledger = ledger
        // Hidden from the first frame only when it's about to tick in.
        _isShown = State(initialValue: !(key.map { ledger.isFresh(key: $0, arrivedAt: arrivedAt) } ?? false))
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isShown ? 1 : Self.fromScale)
            .opacity(isShown ? 1 : 0)
            .onAppear(perform: tick)
    }

    private func tick() {
        guard !isShown else { return }
        let claimed = key.flatMap { ledger.claim(key: $0, arrivedAt: arrivedAt) } != nil
        guard Self.ticks(claimed: claimed, reduceMotion: reduceMotion) else {
            isShown = true
            return
        }
        Task { @MainActor in
            await Task.yield()
            withAnimation(MotionTiming.tick.animation) { isShown = true }
        }
    }

    /// A fresh arrival ticks; never with Reduce Motion.
    nonisolated static func ticks(claimed: Bool, reduceMotion: Bool) -> Bool {
        claimed && !reduceMotion
    }
}

extension View {
    /// Effect 3 on a pill that arrives; see `AITickIn`.
    func aiTickIn(key: String?, arrivedAt: Date?) -> some View {
        modifier(AITickIn(key: key, arrivedAt: arrivedAt))
    }
}
