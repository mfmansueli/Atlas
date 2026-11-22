//
//  ComplianceCard.swift
//  Atlas
//

import SwiftUI

/// One regulation that isn't settled: its name, where it stands, what it
/// asks, and under that the answer's controls.
struct ComplianceCard<Content: View>: View {
    let rule: ComplianceRule
    let state: ComplianceItemState
    let detail: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(rule.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                ComplianceStatePill(state: state)
            }
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).detail")
            content()
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: shape)
        .overlay { shape.strokeBorder(Palette.separator, lineWidth: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card - 2, style: .continuous)
    }
}

#Preview {
    ComplianceCard(
        rule: .icpFilingNumber,
        state: .needsAnswer,
        detail: "Lumen is available in China mainland and has no ICP Filing Number."
    ) {
        Text("Controls")
    }
    .padding()
    .frame(width: 620)
}
