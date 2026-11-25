//
//  PushFlightLayer.swift
//  Atlas
//

import SwiftUI

/// Draws the chips in the air (`PushFlight`) where `PushFlightPath` puts
/// them, each from its own start time, or still at its `frozenAt` in a
/// DEBUG scene. `toLocal` turns a flight's points into this view's,
/// whose y grows downward. Clicks go through.
struct PushFlightLayer: View {
    let flights: [PushFlight]
    var toLocal: (CGPoint) -> CGPoint = { $0 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(flights) { flight in
                Chip(flight: flight, path: PushFlightPath(start: toLocal(flight.start), target: toLocal(flight.target)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One chip, moved frame by frame for the 0.72 s it flies.
    private struct Chip: View {
        let flight: PushFlight
        let path: PushFlightPath

        var body: some View {
            TimelineView(.animation(paused: flight.frozenAt != nil)) { context in
                let elapsed = flight.frozenAt ?? context.date.timeIntervalSince(flight.launchedAt)
                let frame = path.frame(at: elapsed)
                PushFlightChip(label: flight.label)
                    .scaleEffect(frame.scale)
                    .opacity(frame.opacity)
                    .position(frame.point)
            }
        }
    }
}
