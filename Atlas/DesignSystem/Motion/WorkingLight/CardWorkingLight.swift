//
//  CardWorkingLight.swift
//  Atlas
//

import SwiftUI

/// Effect 1 · Working light, on a card (README — Design system §5): while
/// an assistant works on that card, a purple light runs round its edge,
/// 2.2 s linear, the only loop on screen. With Reduce Motion it's a steady
/// purple outline. Laid over the card; it takes no clicks.
struct CardWorkingLight: View {
    var cornerRadius: CGFloat = Radius.card
    var color: Color = Palette.aiFill

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One turn round the card.
    nonisolated static let turn: TimeInterval = 2.2

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if reduceMotion {
                shape.strokeBorder(color, lineWidth: 1.5)
            } else {
                TimelineView(.animation) { context in
                    shape.strokeBorder(
                        AngularGradient(
                            stops: [
                                .init(color: color.opacity(0), location: 0),
                                .init(color: color.opacity(0), location: 0.62),
                                .init(color: color, location: 0.9),
                                .init(color: color.opacity(0), location: 1),
                            ],
                            center: .center,
                            angle: .degrees(Self.angle(at: context.date.timeIntervalSinceReferenceDate))
                        ),
                        lineWidth: 2
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where the light is at `time`, in degrees: a whole turn every 2.2 s.
    nonisolated static func angle(at time: TimeInterval) -> Double {
        (time.truncatingRemainder(dividingBy: turn) / turn) * 360
    }
}

#Preview {
    RoundedRectangle(cornerRadius: Radius.card)
        .fill(Palette.raised)
        .frame(width: 360, height: 160)
        .overlay { CardWorkingLight() }
        .padding()
}
