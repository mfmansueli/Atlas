//
//  AutopilotSparkle.swift
//  Atlas
//

import SwiftUI

/// The Autopilot button's sparkle: a large star and a small one. While it
/// works each shrinks to half, turns 45° and fades to 40% and back every
/// 1.5 s, ease in-out, the small one half a cycle later. With Reduce Motion
/// it stays still, the small star dimmed.
struct AutopilotSparkle: View {
    var isWorking = false
    var color: Color = Palette.ai

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One twinkle.
    static let cycle: TimeInterval = 1.5

    var body: some View {
        if isWorking, !reduceMotion {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                stars(large: Self.twinkle(at: time), small: Self.twinkle(at: time - Self.cycle / 2))
            }
        } else {
            // Still: with Reduce Motion while it works, the small star dimmed.
            stars(large: 0, small: 0, dimsSmall: isWorking)
        }
    }

    /// The design's two stars in a 16 pt square: the large one centered at
    /// (8, 6.5), the small one at (12.6, 12.1).
    private func stars(large: Double, small: Double, dimsSmall: Bool = false) -> some View {
        ZStack(alignment: .topLeading) {
            star(size: 9.6, amount: large)
                .position(x: 8, y: 6.5)
            star(size: 4.4, amount: small)
                .opacity(dimsSmall ? 0.4 : 1)
                .position(x: 12.6, y: 12.1)
        }
        .frame(width: 16, height: 16)
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }

    /// A star `amount` of the way to its smallest (0 full, 1 half size,
    /// turned 45°, 40% opaque).
    private func star(size: CGFloat, amount: Double) -> some View {
        Image(systemName: "sparkle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(1 - 0.5 * amount)
            .rotationEffect(.degrees(45 * amount))
            .opacity(1 - 0.6 * amount)
    }

    /// 0 → 1 → 0 over one cycle, eased in and out: the CSS keyframes'
    /// 0%, 50%, 100% with ease-in-out.
    static func twinkle(at time: TimeInterval) -> Double {
        let phase = (time / cycle).truncatingRemainder(dividingBy: 1)
        let unit = phase < 0 ? phase + 1 : phase
        return (1 - cos(2 * .pi * unit)) / 2
    }
}
