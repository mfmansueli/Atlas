//
//  AISpark.swift
//  Atlas
//

import SwiftUI

/// The Autopilot's spark ✦ (README — Design system §7, v2), the one element
/// that tells the story: it travels from where you asked (`aiTrail`), sits
/// still where the work happens (`aiWorking`) and signs the result. Purple
/// with a soft glow; seen, not read.
struct AISpark: View {
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: "sparkle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Palette.aiFill)
            .shadow(color: Palette.aiFill.opacity(0.55), radius: 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: Spacing.large) {
        AISpark()
        AISpark(size: 20)
    }
    .padding()
}
