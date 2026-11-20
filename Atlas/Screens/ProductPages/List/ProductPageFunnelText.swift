//
//  ProductPageFunnelText.swift
//  Atlas
//

import SwiftUI

/// "151K → 8,050 → 2,550", or why a page has no numbers.
struct ProductPageFunnelText: View {
    let numbers: ProductPageNumbers?
    let emptyText: String

    var body: some View {
        if let numbers {
            Text(ProductPageNumbersText.funnel(numbers))
                .font(.callout)
                .monospacedDigit()
                .lineLimit(1)
                .accessibilityLabel(Text(ProductPageNumbersText.spokenFunnel(numbers)))
        } else {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(Palette.label3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
