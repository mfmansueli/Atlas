//
//  TrailView.swift
//  Atlas
//

import SwiftUI

/// The spark on its trail (effect 1): the Autopilot's ✦ itself, no disc,
/// travelling along `path` from `start`. Seen, not read: hidden from
/// VoiceOver, which hears the send instead. Shown only without Reduce
/// Motion; with it the spark appears still at the place.
struct TrailView: View {
    let path: TrailPath
    let start: Date

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start) - TrailPath.delay
            ZStack(alignment: .topLeading) {
                Color.clear
                if elapsed < path.duration {
                    let state = path.state(at: elapsed)
                    AISpark(size: TrailPath.size)
                        .opacity(state.opacity)
                        .position(state.center)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
