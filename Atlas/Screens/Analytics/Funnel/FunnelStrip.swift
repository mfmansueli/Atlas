//
//  FunnelStrip.swift
//  Atlas
//

import SwiftUI

/// The funnel in one row: a tile per step with its count, joined by the
/// rate from one step to the next. Clicking a rate charts it.
struct FunnelStrip: View {
    let steps: [FunnelStep]
    let selected: FunnelStage
    let onSelect: (FunnelStage) -> Void

    @State private var width: CGFloat = 0

    /// The narrowest a tile reads at.
    private static let tileMinimum: CGFloat = 86

    /// What the strip needs; under it (a narrow window with the sidebar
    /// open) it scrolls sideways instead of squeezing its tiles.
    private var minimumWidth: CGFloat {
        let rates = CGFloat(steps.count { $0.stage.previous != nil })
        return CGFloat(steps.count) * Self.tileMinimum + rates * FunnelRateButton.width + CGFloat(max(steps.count * 2 - 2, 0)) * Spacing.xSmall
    }

    var body: some View {
        Group {
            if width > 0, width < minimumWidth {
                ScrollView(.horizontal) {
                    strip.frame(width: minimumWidth).padding(.bottom, Spacing.small)
                }
            } else {
                strip
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }

    private var strip: some View {
        HStack(alignment: .top, spacing: Spacing.xSmall) {
            ForEach(steps) { step in
                if step.stage.previous != nil {
                    FunnelRateButton(step: step, isSelected: selected == step.stage) { onSelect(step.stage) }
                }
                FunnelStepTile(step: step)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Funnel"))
        .accessibilityIdentifier("analytics.funnel.strip")
    }
}
