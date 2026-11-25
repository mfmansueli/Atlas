//
//  PriceChangePill.swift
//  Atlas
//

import SwiftUI

/// A price's change in Pricing's table and popover (board 73): "▼ −48%" in
/// grey, "▲ +17%" in amber. Nothing when the price doesn't move.
struct PriceChangePill: View {
    let change: PriceChange

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if change.direction != .none {
            HStack(spacing: 3) {
                if let symbol = change.pillSystemImage {
                    Image(systemName: symbol)
                        .imageScale(.small)
                }
                Text(change.pillText)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .atlasTextStyle(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(change.pillTint)
            .padding(.horizontal, Spacing.xSmall)
            .frame(minHeight: 20)
            .background(change.pillBackground, in: Capsule())
            .overlay {
                if contrast == .increased { Capsule().strokeBorder(change.pillTint, lineWidth: 1) }
            }
            .fixedSize()
            .accessibilityElement()
            .accessibilityLabel(Text(accessibilityText))
        }
    }

    private var accessibilityText: String {
        change.direction == .increase
            ? String(localized: "Up \(abs(change.percent)) percent", comment: "kind:accessibility-label")
            : String(localized: "Down \(abs(change.percent)) percent", comment: "kind:accessibility-label")
    }
}

#Preview {
    HStack {
        PriceChangePill(change: PriceChange(old: 249.9, new: 129.9))
        PriceChangePill(change: PriceChange(old: 10, new: 11.7))
    }
    .padding()
}
