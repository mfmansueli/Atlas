//
//  AssistantWorkingDot.swift
//  Atlas
//

import SwiftUI

/// The toolbar Assistant button's dot while a request runs: suggestion
/// purple, pulsing every 1.1 s; still with Reduce Motion.
struct AssistantWorkingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLarge = false

    var body: some View {
        Circle()
            .fill(Palette.suggestionBadge)
            .frame(width: 8, height: 8)
            .scaleEffect(reduceMotion ? 1 : isLarge ? 1.25 : 0.7)
            .opacity(reduceMotion ? 1 : isLarge ? 1 : 0.55)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { isLarge = true }
            }
            .accessibilityHidden(true)
    }
}
