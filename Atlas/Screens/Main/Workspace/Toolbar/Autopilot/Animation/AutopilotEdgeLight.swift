//
//  AutopilotEdgeLight.swift
//  Atlas
//

import SwiftUI

/// The light that travels along the Autopilot button's edge while it
/// works: a purple band crossing a 1.5 pt outline from left to right every
/// 2.2 s, linear. With Reduce Motion it's a steady purple outline.
struct AutopilotEdgeLight: View {
    var color: Color = Palette.suggestionBadge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One pass along the edge.
    static let pass: TimeInterval = 2.2
    /// Half the band's width, as a share of the button's: a third of a
    /// gradient three times as wide.
    static let halfBand = 0.48

    var body: some View {
        Group {
            if reduceMotion {
                Capsule().strokeBorder(color, lineWidth: 1.5)
            } else {
                TimelineView(.animation) { context in
                    let center = Self.bandCenter(at: context.date.timeIntervalSinceReferenceDate)
                    Capsule().strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: color.opacity(0), location: 0), .init(color: color, location: 0.5), .init(color: color.opacity(0), location: 1),
                            ],
                            startPoint: UnitPoint(x: center - Self.halfBand, y: 0.5),
                            endPoint: UnitPoint(x: center + Self.halfBand, y: 0.5)
                        ),
                        lineWidth: 1.5
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where the band's middle is, as a share of the button's width: from
    /// half a width before its left edge to half a width past its right.
    static func bandCenter(at time: TimeInterval) -> Double {
        let phase = (time / pass).truncatingRemainder(dividingBy: 1)
        let unit = phase < 0 ? phase + 1 : phase
        return -0.5 + 2 * unit
    }
}
