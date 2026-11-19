//
//  AskFlightView.swift
//  Atlas
//

import SwiftUI

/// The token on its way to the toolbar, then one ring around the Assistant
/// button as it lands. Seen, not read: hidden from VoiceOver, which hears
/// the send instead.
struct AskFlightView: View {
    let path: AskTokenPath
    /// The Assistant button, in this view's top-left points.
    let target: CGRect
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            ZStack(alignment: .topLeading) {
                Color.clear
                if elapsed < AskTokenPath.landing {
                    let state = path.state(at: elapsed - AskTokenPath.delay)
                    Token()
                        .scaleEffect(state.scale)
                        .opacity(state.opacity)
                        .position(state.center)
                }
                if let ring = AskTokenPath.ring(at: elapsed - AskTokenPath.landing) {
                    // The stroke's inner edge sits on the button's.
                    Capsule()
                        .stroke(Palette.suggestionBadge.opacity(ring.opacity), lineWidth: ring.spread)
                        .frame(width: target.width + ring.spread, height: target.height + ring.spread)
                        .position(x: target.midX, y: target.midY)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A purple disc with the suggestion sparkle.
    private struct Token: View {
        var body: some View {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.suggestionBadgeText)
                .frame(width: AskTokenPath.size, height: AskTokenPath.size)
                .background(Palette.suggestionBadge, in: Circle())
                .background(Circle().stroke(Palette.suggestionBusyTint, lineWidth: 8))
                .shadow(color: Palette.suggestionBadge.opacity(0.45), radius: 9, y: 6)
        }
    }
}
