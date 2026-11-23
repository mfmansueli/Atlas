//
//  AIDecided.swift
//  Atlas
//

import SwiftUI

/// Effect 4 · Accepted · Dismissed · Undone (README — Design system §7,
/// v2): every decision has its motion, the way back too.
///
/// - Accept: the purple goes to neutral (motion.base, 0.25 s) and a check
///   draws itself (0.3 s); then the accept is made, and the card gives way
///   to the item it changed, which stays where it was and reads “Not
///   pushed”. The card fades; it doesn't close.
/// - Dismiss: the purple drains and the card closes (motion.layout, spring
///   0.35 s) while what's below moves up.
/// - Undo: the item comes back sliding down 6 pt, no light.
///
/// With Reduce Motion each is a direct swap with a 0.15 s fade
/// (motion.fast). The card keeps `isSettling` (accepted, settling) and
/// decides through `accept` and `dismiss`; while it settles it takes no more
/// clicks.
struct AIDecided: ViewModifier {
    let isSettling: Bool
    var checkAlignment: Alignment = .topTrailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far an undone item slides down as it comes back.
    static let undoSlide: CGFloat = 6
    /// The check draws a moment after the tint starts to go.
    static let checkDraw = Animation.easeOut(duration: 0.3).delay(0.05)
    /// How long the tint and the check play before the accept is made.
    static let acceptDelay: Duration = .milliseconds(400)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: checkAlignment) {
                if isSettling, !reduceMotion {
                    AcceptCheckMark()
                        .padding(Spacing.xSmall)
                }
            }
            .allowsHitTesting(!isSettling)
            .transition(Self.transition(isAccepted: isSettling, reduceMotion: reduceMotion))
    }

    /// Coming back (an undo) it slides down 6 pt; leaving accepted it
    /// fades into its item; dismissed it closes. Reduce Motion fades.
    static func transition(isAccepted: Bool, reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        let removal: AnyTransition = isAccepted
            ? .opacity
            : .modifier(active: Collapse(isClosed: true), identity: Collapse(isClosed: false)).combined(with: .opacity)
        return .asymmetric(insertion: .offset(y: -undoSlide).combined(with: .opacity), removal: removal)
    }

    /// How long the tint and check play before the accept is made.
    static func commitDelay(reduceMotion: Bool) -> Duration {
        reduceMotion ? .zero : acceptDelay
    }

    /// The animation a decision is made in: the layout spring, or Reduce
    /// Motion's fade.
    static func commitAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? MotionTiming.fast.animation : MotionTiming.layout.animation
    }

    /// Accept: `settle` turns the card's `isSettling` on, `commit` makes the
    /// change that takes the suggestion into its item. An async accept
    /// should start with `Task.immediate` so its first, synchronous change
    /// is still made in the spring.
    static func accept(reduceMotion: Bool, settle: () -> Void, commit: @escaping @MainActor () -> Void) {
        let animation = commitAnimation(reduceMotion: reduceMotion)
        guard !reduceMotion else {
            withAnimation(animation) {
                settle()
                commit()
            }
            return
        }
        withAnimation(MotionTiming.base.animation) { settle() }
        let delay = commitDelay(reduceMotion: reduceMotion)
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            withAnimation(animation) { commit() }
        }
    }

    /// Dismiss: the card drains and closes in the layout spring.
    static func dismiss(reduceMotion: Bool, commit: () -> Void) {
        withAnimation(commitAnimation(reduceMotion: reduceMotion)) { commit() }
    }

    /// Undo: what comes back slides down into its place.
    static func undo(reduceMotion: Bool, commit: () -> Void) {
        withAnimation(commitAnimation(reduceMotion: reduceMotion)) { commit() }
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

extension View {
    /// Effect 4 on a suggestion card; see `AIDecided`.
    func aiDecided(isSettling: Bool, checkAlignment: Alignment = .topTrailing) -> some View {
        modifier(AIDecided(isSettling: isSettling, checkAlignment: checkAlignment))
    }
}
