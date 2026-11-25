//
//  CatalogSentSection.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// “Sent to Review & Push” (board 80) playing with the real views: a chip
/// rises from Accept and arcs to Review & Push, which pulses as it lands
/// and its count goes up. It plays again every few seconds and on Play
/// Again; with the catalog's Reduce Motion only the count changes.
struct CatalogSentSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flight: PushFlight?
    @State private var count = 2
    @State private var landings = 0
    @State private var size = CGSize.zero

    var body: some View {
        CatalogSection(
            title: "Sent to Review & Push",
            note: "Blue: the person did this. Lift 0.12 s, arc 0.6 s, then a 0.5 s pulse and a 0.7 s ring. Reduce Motion: the count only."
        ) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Button("Play Again") { send() }
                ZStack(alignment: .bottomTrailing) {
                    Text("Accept")
                        .atlasTextStyle(.body)
                        .padding(.horizontal, Spacing.small)
                        .padding(.vertical, Spacing.xxSmall)
                        .background(Palette.accentTint, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(Spacing.large)
                    ReviewPushPillFace(state: .pending(count), landings: landings) {}
                        .padding(Spacing.small)
                    PushFlightLayer(flights: flight.map { [$0] } ?? [])
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(Palette.content, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: CatalogEffectsSection.cycle)
                send()
            }
        }
    }

    /// One accept: the chip flies, then the pill takes it.
    private func send() {
        guard !reduceMotion, size != .zero else {
            count += 1
            return
        }
        let start = CGPoint(x: Spacing.large + 30, y: Spacing.large + 12)
        let target = CGPoint(x: size.width - 90, y: size.height - Spacing.small - Metrics.reviewPushPillHeight / 2)
        let sent = PushFlight(label: "What’s New · German", start: start, target: target)
        flight = sent
        Task {
            try? await Task.sleep(for: .seconds(PushFlightPath.duration))
            guard flight?.id == sent.id else { return }
            flight = nil
            landings += 1
            withAnimation(MotionTiming.tick.animation) { count += 1 }
        }
    }
}
#endif
