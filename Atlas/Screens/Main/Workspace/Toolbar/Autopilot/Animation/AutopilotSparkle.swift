//
//  AutopilotSparkle.swift
//  Atlas
//

import SwiftUI

/// The Autopilot button's sparkle: a large star and a small one. Motion v2
/// (README — Design system §7): it never twinkles or pulses; while
/// something runs it stays still, the small star dimmed, and the bar is the
/// progress.
struct AutopilotSparkle: View {
    var isWorking = false
    var color: Color = Palette.ai

    var body: some View {
        ZStack(alignment: .topLeading) {
            star(size: 9.6)
                .position(x: 8, y: 6.5)
            star(size: 4.4)
                .opacity(isWorking ? 0.4 : 1)
                .position(x: 12.6, y: 12.1)
        }
        .frame(width: 16, height: 16)
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }

    /// The design's two stars in a 16 pt square: the large one centered at
    /// (8, 6.5), the small one at (12.6, 12.1).
    private func star(size: CGFloat) -> some View {
        Image(systemName: "sparkle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
