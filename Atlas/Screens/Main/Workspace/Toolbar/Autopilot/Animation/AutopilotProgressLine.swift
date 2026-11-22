//
//  AutopilotProgressLine.swift
//  Atlas
//

import SwiftUI

/// The 2 pt bar inside the bottom of the Autopilot button while a run
/// counts its steps; it eases to each new value in 0.7 s, and jumps there
/// with Reduce Motion.
struct AutopilotProgressLine: View {
    /// 0–1.
    let value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(Palette.fill2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Palette.suggestionBadge)
                        .frame(width: proxy.size.width * value)
                }
        }
        .frame(height: 2)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: value)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
