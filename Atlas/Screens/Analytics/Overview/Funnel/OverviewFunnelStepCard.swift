//
//  OverviewFunnelStepCard.swift
//  Atlas
//

import SwiftUI

/// One step of "From impression to paid": how many got there, the share of
/// the step before in words, and Worse / Better / About the same with the
/// difference in points; how sure is in the tooltip. Selected, it's the
/// step the chart shows.
struct OverviewFunnelStepCard: View {
    let step: FunnelStepSummary
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(step.title)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.count)
                    .atlasTextStyle(.title2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(step.isGap ? Palette.label3 : Palette.label)
                if let sentence = step.sentence {
                    Text(sentence)
                        .atlasTextStyle(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(step.isGap ? Palette.warn : Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                verdict
                Spacer(minLength: 0)
            }
            .padding(Spacing.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isSelected ? Palette.accentTint : Palette.raised, in: shape)
            .overlay {
                shape.strokeBorder(isSelected ? Palette.accent : edge, lineWidth: isSelected || contrast == .increased ? 1 : 0.5)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(step.tooltip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.accessibilityText))
        .accessibilityHint(Text("Shows it on the chart", comment: "kind:accessibility-hint · a funnel step card"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("analytics.funnel.step.\(step.stage.rawValue)")
    }

    @ViewBuilder
    private var verdict: some View {
        if let verdict = step.verdict {
            FlowLayout(spacing: Spacing.xxSmall) {
                Pill(text: verdict.title, style: verdict.pillStyle)
                if let points = step.points {
                    Text(points)
                        .atlasTextStyle(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.label2)
                }
            }
        } else if let plain = step.plainWord {
            Text(plain)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var edge: Color {
        contrast == .increased ? Palette.separator2 : Palette.separator
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }
}
