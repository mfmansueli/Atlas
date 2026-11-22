//
//  AcceptSettle.swift
//  Atlas
//

import SwiftUI

/// Effect 5 · Accept settles: once the person accepts a suggestion its
/// purple tint goes (0.25 s, the card draws that from `isSettling`), a check
/// draws itself (0.3 s), and then the card's height springs closed (0.35 s)
/// while what's below moves up. With Reduce Motion it's a 0.15 s
/// cross-fade instead.
///
/// The card keeps `isSettling` and accepts through `perform`, which plays the
/// tint and check, then commits in the closing spring. While it settles the
/// card takes no more clicks.
struct AcceptSettle: ViewModifier {
    let isSettling: Bool
    var checkAlignment: Alignment = .topTrailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: checkAlignment) {
                if isSettling, !reduceMotion {
                    AcceptCheckMark()
                        .padding(Spacing.xSmall)
                }
            }
            .allowsHitTesting(!isSettling)
            .transition(Self.transition(isSettling: isSettling, reduceMotion: reduceMotion))
    }

    /// How the card leaves: closing when it was accepted, a fade otherwise
    /// (Dismiss, Accept All) and always with Reduce Motion.
    static func transition(isSettling: Bool, reduceMotion: Bool) -> AnyTransition {
        guard isSettling, !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity,
            removal: .modifier(active: Collapse(isClosed: true), identity: Collapse(isClosed: false)).combined(with: .opacity)
        )
    }

    /// How long the tint and check play before the card closes.
    static func commitDelay(reduceMotion: Bool) -> Duration {
        reduceMotion ? .zero : MotionTiming.acceptCommitDelay
    }

    /// The animation the accept itself is committed in.
    static func commitAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? MotionTiming.reducedCrossFade : MotionTiming.layoutSpring
    }

    /// Accept: `settle` turns the card's `isSettling` on, `commit` makes the
    /// change that takes the card away. An async accept should start with
    /// `Task.immediate` so its first, synchronous change still closes the
    /// card in the spring.
    static func perform(reduceMotion: Bool, settle: () -> Void, commit: @escaping @MainActor () -> Void) {
        let animation = commitAnimation(reduceMotion: reduceMotion)
        guard !reduceMotion else {
            withAnimation(animation) {
                settle()
                commit()
            }
            return
        }
        withAnimation(MotionTiming.acceptTint) { settle() }
        let delay = commitDelay(reduceMotion: reduceMotion)
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            withAnimation(animation) { commit() }
        }
    }

    /// The closing: no height, clipped at the top.
    private struct Collapse: ViewModifier {
        let isClosed: Bool

        func body(content: Content) -> some View {
            content
                .frame(height: isClosed ? 0 : nil, alignment: .top)
                .clipped()
        }
    }
}
