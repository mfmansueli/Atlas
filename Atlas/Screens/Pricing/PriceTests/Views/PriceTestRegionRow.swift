//
//  PriceTestRegionRow.swift
//  Atlas
//

import SwiftUI

/// A Region choice in Test a Price: "Europe", "14 countries · 2,140 page
/// views · 96 starts", and Too few or In a test beside it.
struct PriceTestRegionRow: View {
    let option: PriceTestRegionOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            RadioRow(title: option.region.title, detail: option.detail, isSelected: isSelected, isDisabled: !option.isAvailable, action: onSelect)
            if option.isUnderTest {
                Pill(text: String(localized: "In a test", comment: "kind:pill"))
                    .fixedSize()
            } else if !option.isEnough {
                Pill(text: String(localized: "Too few", comment: "kind:pill"), style: .warning)
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("priceTest.region.\(option.region.rawValue)")
    }
}
