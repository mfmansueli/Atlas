//
//  AIArrived.swift
//  Atlas
//

import SwiftUI

/// Effect 3 · Arrived, on a card or row (README — Design system §7, v2): a
/// suggestion that lands where the person is looking fades its tint in over
/// 0.4 s (motion.slow); no light pass. Several at once arrive 70 ms apart,
/// at most six moving; one that lands out of sight appears still and counts
/// in “3 new below” (`ArrivalsOffScreen`). With Reduce Motion it fades in
/// over 0.2 s. Images use `aiArrivedImage`, text `SuggestedText`.
///
/// Only a fresh arrival plays (`ArrivalLedger`): what was already there when
/// the page appeared, a built-in check's suggestion or a loaded file stays
/// still. The card's `key` is what it shows, so a suggestion replacing
/// another under the same field arrives again.
struct AIArrived: ViewModifier {
    let key: String
    /// When it arrived; nil never plays.
    let arrivedAt: Date?
    var window = ArrivalLedger.suggestionWindow
    var ledger: ArrivalLedger = .shared
    var offScreen: ArrivalsOffScreen = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown: Bool
    @State private var isVisible = true

    /// Reduce Motion's fade.
    static let reducedFade = Animation.easeOut(duration: 0.2)

    init(
        key: String,
        arrivedAt: Date?,
        window: TimeInterval = ArrivalLedger.suggestionWindow,
        ledger: ArrivalLedger = .shared,
        offScreen: ArrivalsOffScreen = .shared
    ) {
        self.key = key
        self.arrivedAt = arrivedAt
        self.window = window
        self.ledger = ledger
        self.offScreen = offScreen
        // Hidden from the first frame only when it's about to arrive.
        _isShown = State(initialValue: !ledger.isFresh(key: key, arrivedAt: arrivedAt, window: window))
    }

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .onScrollVisibilityChange(threshold: 0.2) { visible in
                isVisible = visible
                if visible { offScreen.remove(key) }
            }
            .onAppear(perform: arrive)
            .onDisappear { offScreen.remove(key) }
    }

    private func arrive() {
        guard !isShown else { return }
        guard let place = ledger.claim(key: key, arrivedAt: arrivedAt, window: window),
              let delay = MotionTiming.staggerDelay(for: place)
        else {
            isShown = true
            return
        }
        Task { @MainActor in
            // The scroll view says whether the card is in sight first.
            await Task.yield()
            guard isVisible else {
                isShown = true
                offScreen.add(key)
                return
            }
            let animation = reduceMotion ? Self.reducedFade : MotionTiming.slow.animation
            withAnimation(animation.delay(reduceMotion ? 0 : delay)) { isShown = true }
        }
    }
}

extension View {
    /// Effect 3 · Arrived on a suggestion card or row; see `AIArrived`.
    func aiArrived(key: String, arrivedAt: Date?, window: TimeInterval = ArrivalLedger.suggestionWindow) -> some View {
        modifier(AIArrived(key: key, arrivedAt: arrivedAt, window: window))
    }
}
