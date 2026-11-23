//
//  AIFailureArrival.swift
//  Atlas
//

import SwiftUI

/// Effect 5 · Needs you, when the work failed (README — Design system §7,
/// v2): a failure is never purple and never shakes. Its amber notice slides
/// in 4 pt (motion.base) and stays, with what to do next. Put it on the
/// view that holds the notice and stays while the state changes, with the
/// failure's `key` (nil while there's none): only a failure that happens
/// while the person looks moves; one already there when the page opens is
/// still. With Reduce Motion it appears at once.
struct AIFailureArrival: ViewModifier {
    let key: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slide: CGFloat = 0
    @State private var opacity: Double = 1

    /// How far the notice slides in.
    static let distance: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .offset(y: slide)
            .opacity(opacity)
            .onChange(of: key) { old, new in
                guard Self.slides(from: old, to: new, reduceMotion: reduceMotion) else { return }
                slide = -Self.distance
                opacity = 0
                withAnimation(MotionTiming.base.animation) {
                    slide = 0
                    opacity = 1
                }
            }
    }

    /// A new failure slides in; the same one, or none, stays still.
    nonisolated static func slides(from old: String?, to new: String?, reduceMotion: Bool) -> Bool {
        new != nil && new != old && !reduceMotion
    }
}

extension View {
    /// Effect 5 on a failure's amber notice; see `AIFailureArrival`.
    func aiFailureArrival(key: String?) -> some View {
        modifier(AIFailureArrival(key: key))
    }
}
