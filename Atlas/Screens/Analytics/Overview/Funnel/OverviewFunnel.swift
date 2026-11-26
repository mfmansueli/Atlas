//
//  OverviewFunnel.swift
//  Atlas
//

import SwiftUI

/// "From impression to paid" (board 92): five step cards with a chevron
/// between them, the note under them. Clicking a card charts it. Where the
/// cards don't fit (a narrow window with the sidebar open) they scroll
/// sideways instead of being cut.
struct OverviewFunnel: View {
    let steps: [FunnelStepSummary]
    let selected: FunnelStage
    var note: String?
    let onSelect: (FunnelStepSummary) -> Void

    @State private var width: CGFloat = 0

    /// What the cards need side by side.
    private var minimumWidth: CGFloat {
        let count = CGFloat(steps.count)
        let joints = CGFloat(max(steps.count - 1, 0))
        return count * Metrics.analyticsFunnelCardMinWidth + joints * (Spacing.medium + 2 * Spacing.xxSmall)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text("From impression to paid", comment: "kind:heading · Analytics Overview")
                    .atlasTextStyle(.title3)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "Each step: how many got there, and what share of the step before. Click a step to chart it.",
                    comment: "kind:description · Analytics Overview funnel"
                )
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
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
            if let note {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Palette.label2)
                        .accessibilityHidden(true)
                    Text(note)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("analytics.funnel.note")
            }
        }
    }

    private var strip: some View {
        HStack(alignment: .center, spacing: Spacing.xxSmall) {
            ForEach(steps) { step in
                if step.stage.previous != nil {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(Palette.label3)
                        .frame(width: Spacing.medium)
                        .accessibilityHidden(true)
                }
                OverviewFunnelStepCard(step: step, isSelected: step.stage == selected) { onSelect(step) }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Funnel", comment: "kind:accessibility-label · Analytics Overview"))
        .accessibilityIdentifier("analytics.funnel.strip")
    }
}
