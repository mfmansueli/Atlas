//
//  ArrivalEdgePass.swift
//  Atlas
//

import SwiftUI

/// The arrival's one light pass round a card's edge: a purple tail on a
/// 1.5 pt outline that goes once round, 1.1 s ease-out, fading in at the
/// start and out at the end (board 64's `pass`). Drawn while `startedAt`
/// is recent; the modifier takes it away when it's done.
struct ArrivalEdgePass<S: InsettableShape>: View {
    let shape: S
    let startedAt: Date

    var body: some View {
        TimelineView(.animation) { context in
            let progress = Self.progress(elapsed: context.date.timeIntervalSince(startedAt))
            shape
                .strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: Palette.suggestionBadge.opacity(0), location: 0),
                            .init(color: Palette.suggestionBadge.opacity(0), location: 250 / 360),
                            .init(color: Palette.suggestionBadge, location: 330 / 360),
                            .init(color: Palette.suggestionBadge.opacity(0), location: 1),
                        ],
                        center: .center,
                        angle: .degrees(Self.angle(progress: progress))
                    ),
                    lineWidth: 1.5
                )
                .opacity(Self.opacity(progress: progress))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How far round, eased out: 0 at the start, 1 once 1.1 s have passed.
    nonisolated static func progress(elapsed: TimeInterval) -> Double {
        let linear = min(max(elapsed / MotionTiming.arrivalPassDuration, 0), 1)
        return UnitCurve.easeOut.value(at: linear)
    }

    /// Where the light's head is, in degrees from the top.
    nonisolated static func angle(progress: Double) -> Double {
        progress * 360
    }

    /// In over the first 8 %, out over the last 25 %.
    nonisolated static func opacity(progress: Double) -> Double {
        if progress < 0.08 { return progress / 0.08 }
        if progress > 0.75 { return max(0, (1 - progress) / 0.25) }
        return 1
    }
}
