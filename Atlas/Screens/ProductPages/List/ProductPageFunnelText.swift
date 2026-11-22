//
//  ProductPageFunnelText.swift
//  Atlas
//

import SwiftUI

/// "151K → 8,050 → 2,550" and where its visitors came from, or why a page
/// has no numbers.
struct ProductPageFunnelText: View {
    let numbers: ProductPageNumbers?
    let emptyText: String

    var body: some View {
        if let numbers {
            VStack(alignment: .leading, spacing: 1) {
                Text(ProductPageNumbersText.funnel(numbers))
                    .font(.callout)
                    .monospacedDigit()
                    .lineLimit(1)
                    .accessibilityLabel(Text(ProductPageNumbersText.spokenFunnel(numbers)))
                // Where the page's link is used.
                if let arrivals = ProductPageNumbersText.arrivals(numbers.arrivals) {
                    Text(arrivals)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .help(Text(numbers.arrivals.prefix(5).map(\.title).joined(separator: "\n")))
                        .accessibilityIdentifier("pages.row.arrivals")
                }
            }
        } else {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
