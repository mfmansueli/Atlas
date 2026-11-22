//
//  SuggestionArrival.swift
//  Atlas
//

import SwiftUI

/// Effect 2 · Arrival: a suggestion that lands where the person is looking
/// fades in over 0.4 s, and one light passes round its edge, 1.1 s
/// ease-out, once. With Reduce Motion only the tint fades in. A new image
/// (event artwork, Autopilot's captures) fades in without the edge pass.
///
/// Only a fresh arrival plays (`ArrivalLedger`): what was already there when
/// the page appeared, a built-in check's suggestion or a loaded file stays
/// still. The card's `key` is what it shows, so a suggestion replacing
/// another under the same field arrives again.
struct SuggestionArrival<S: InsettableShape>: ViewModifier {
    let key: String
    /// When it arrived; nil never plays.
    let arrivedAt: Date?
    let shape: S
    var edgePass = true
    var window = ArrivalLedger.suggestionWindow
    var ledger: ArrivalLedger = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown: Bool
    @State private var passStartedAt: Date?

    init(
        key: String,
        arrivedAt: Date?,
        shape: S,
        edgePass: Bool = true,
        window: TimeInterval = ArrivalLedger.suggestionWindow,
        ledger: ArrivalLedger = .shared
    ) {
        self.key = key
        self.arrivedAt = arrivedAt
        self.shape = shape
        self.edgePass = edgePass
        self.window = window
        self.ledger = ledger
        // Hidden from the first frame only when it's about to arrive.
        _isShown = State(initialValue: !ledger.isFresh(key: key, arrivedAt: arrivedAt, window: window))
    }

    func body(content: Content) -> some View {
        content
            .opacity(isShown ? 1 : 0)
            .overlay {
                if let passStartedAt {
                    ArrivalEdgePass(shape: shape, startedAt: passStartedAt)
                }
            }
            .onAppear(perform: arrive)
    }

    private func arrive() {
        guard !isShown else { return }
        guard ledger.claim(key: key, arrivedAt: arrivedAt, window: window) else {
            isShown = true
            return
        }
        withAnimation(MotionTiming.arrivalTint) { isShown = true }
        guard edgePass, !reduceMotion else { return }
        let start = Date.now
        passStartedAt = start
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(MotionTiming.arrivalPassDuration))
            if passStartedAt == start { passStartedAt = nil }
        }
    }
}
