//
//  AutopilotDoneMark.swift
//  Atlas
//

import SwiftUI

/// The green check the Autopilot button shows once a run is done: it draws
/// itself in 0.35 s (the symbol's Draw On effect, macOS 26), or appears at
/// once with Reduce Motion.
struct AutopilotDoneMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        ZStack {
            if isShown {
                Image(systemName: "checkmark")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(Palette.ok)
                    .transition(.symbolEffect(.drawOn.wholeSymbol))
            }
        }
        .frame(width: 16, height: 16)
        .onAppear {
            if reduceMotion {
                isShown = true
            } else {
                withAnimation(.easeOut(duration: 0.35).delay(0.1)) { isShown = true }
            }
        }
        .accessibilityHidden(true)
    }
}
