//
//  AIProgressBar.swift
//  Atlas
//

import SwiftUI

/// Effect 2 · Working, the bar (README — Design system §7, v2): only for
/// countable units. It moves in steps, one unit at a time, each sliding
/// 0.5 s (motion.step); between steps a soft sweep runs over the filled
/// part only, 2.8 s with a pause between passes, the one loop on screen:
/// still working, without faking progress. With Reduce Motion the bar
/// jumps and there's no sweep.
struct AIProgressBar: View {
    /// 0–1.
    let value: Double
    /// Whether the work still runs; a finished or paused bar doesn't sweep.
    var isWorking = true
    var height: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let filled = proxy.size.width * min(max(value, 0), 1)
            Capsule()
                .fill(Palette.fill2)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.aiFill, Palette.aiMark], startPoint: .leading, endPoint: .trailing))
                        .overlay { sweep(width: filled) }
                        .clipShape(Capsule())
                        .frame(width: filled)
                }
        }
        .frame(height: height)
        .animation(reduceMotion ? nil : MotionTiming.step.animation, value: value)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func sweep(width: CGFloat) -> some View {
        if isWorking, !reduceMotion, width > 0 {
            TimelineView(.animation) { context in
                let state = Self.sweep(at: context.date.timeIntervalSinceReferenceDate)
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0), .init(color: .white.opacity(0.12), location: 0.3),
                        .init(color: .white.opacity(0.42), location: 0.5), .init(color: .white.opacity(0.12), location: 0.7),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.9)
                .offset(x: width * 0.9 * state.offset)
                .opacity(state.opacity)
                .frame(width: width, alignment: .leading)
            }
        }
    }

    /// The sweep at `time`: where its band is (its own widths from the
    /// left, −1 to 1.2) and how strong. It crosses in the first 74 % of a
    /// 2.8 s pass, in over 12 %, out over the last 12 % of the crossing,
    /// then pauses.
    nonisolated static func sweep(at time: TimeInterval) -> (offset: Double, opacity: Double) {
        let phase = (time / MotionTiming.sweep).truncatingRemainder(dividingBy: 1)
        let unit = phase < 0 ? phase + 1 : phase
        let crossing = 0.74
        guard unit < crossing else { return (1.2, 0) }
        let eased = UnitCurve.easeInOut.value(at: unit / crossing)
        let opacity = if unit < 0.12 {
            unit / 0.12
        } else if unit < 0.62 {
            1.0
        } else {
            max(0, 1 - (unit - 0.62) / 0.12)
        }
        return (-1 + 2.2 * eased, opacity)
    }
}

#Preview {
    VStack(spacing: Spacing.large) {
        AIProgressBar(value: 2.0 / 3)
        AIProgressBar(value: 97.0 / 255, height: 4)
        AIProgressBar(value: 1, isWorking: false)
    }
    .frame(width: 280)
    .padding()
}
