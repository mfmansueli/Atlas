//
//  FunnelRateButton.swift
//  Atlas
//

import SwiftUI

/// The rate between two steps: the percentage with its confidence meter,
/// and how it compares with the previous period. Selected, it has the
/// accent ring and drives the chart.
struct FunnelRateButton: View {
    let step: FunnelStep
    let isSelected: Bool
    let onSelect: () -> Void

    static let width: CGFloat = 104

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text(step.stage.rateTitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                RateLabel(rate: step.rate, font: .title3.weight(.bold))
                if let comparison = step.comparison {
                    if !comparison.pointsText.isEmpty {
                        Text(comparison.pointsText)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(comparison.outcome.isLower ? Palette.warn : Palette.label2)
                    }
                    Text(comparison.outcome.title)
                        .font(.subheadline)
                        .foregroundStyle(comparison.outcome.isLower ? Palette.warn : Palette.label2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(width: Self.width)
            .frame(minHeight: 74, maxHeight: .infinity)
            .background(isSelected ? Palette.accentTint : Color.clear, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
                    .strokeBorder(isSelected ? Palette.accent : Color.clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityHint(Text("Shows it on the chart"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("analytics.funnel.rate.\(step.stage.rawValue)")
    }

    private var accessibilityText: String {
        let rate = "\(step.stage.rateTitle): \(step.rate.text)"
        guard let comparison = step.comparison else { return rate }
        return String(localized: "\(rate). \(comparison.pointsText) \(comparison.outcome.title)", comment: "kind:button")
    }
}
