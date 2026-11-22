//
//  AutopilotGlint.swift
//  Atlas
//

import SwiftUI

/// The first-time glint on the Autopilot button (effect 6): 0.8 s after
/// `FirstConnectionGlint` is armed, one soft purple sheen sweeps across the
/// capsule from left to right in 1.2 s, once (board 64's `gl`). With Reduce
/// Motion nothing plays, and it's marked shown all the same.
struct AutopilotGlint: ViewModifier {
    var glint: FirstConnectionGlint = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let startedAt {
                    sheen(startedAt: startedAt)
                }
            }
            .task(id: glint.isArmed) { await play() }
    }

    private func sheen(startedAt: Date) -> some View {
        TimelineView(.animation) { context in
            let position = Self.bandPosition(elapsed: context.date.timeIntervalSince(startedAt))
            GeometryReader { proxy in
                let width = proxy.size.width * Self.bandWidth
                LinearGradient(
                    colors: [Palette.suggestionBadge.opacity(0), Palette.suggestionBadge.opacity(0.35), Palette.suggestionBadge.opacity(0)],
                    startPoint: UnitPoint(x: 0, y: 0.4),
                    endPoint: UnitPoint(x: 1, y: 0.6)
                )
                .frame(width: width, height: proxy.size.height)
                .offset(x: proxy.size.width * position)
            }
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func play() async {
        guard glint.isArmed else { return }
        guard !reduceMotion else {
            glint.markShown()
            return
        }
        try? await Task.sleep(for: MotionTiming.glintDelay)
        guard !Task.isCancelled, glint.isArmed else { return }
        startedAt = .now
        try? await Task.sleep(for: .seconds(MotionTiming.glintDuration))
        startedAt = nil
        glint.markShown()
    }

    /// The band's width, as a share of the button's.
    static let bandWidth = 0.4

    /// Where the band's left edge is, as a share of the button's width:
    /// from half a width before the button to past its right edge, eased in
    /// and out.
    nonisolated static func bandPosition(elapsed: TimeInterval) -> Double {
        let linear = min(max(elapsed / MotionTiming.glintDuration, 0), 1)
        return -0.5 + 1.7 * UnitCurve.easeInOut.value(at: linear)
    }
}
