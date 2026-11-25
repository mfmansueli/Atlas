//
//  PriceTestResultsHeader.swift
//  Atlas
//

import SwiftUI

/// The top of Results (board 76, `pt-res`): what the tab shows and Test a
/// Price…, which shows PRO on Free and opens the paywall (`pt-res-free`).
struct PriceTestResultsHeader: View {
    let isFree: Bool
    let onTest: () -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text("What each price change and price test did, country by country.", comment: "kind:description")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onTest) {
                HStack(spacing: Spacing.xSmall) {
                    Text("Test a Price…", comment: "kind:button")
                    if isFree { ProChip() }
                }
            }
            .secondaryButton()
            .fixedSize()
            .accessibilityIdentifier("pricing.results.testPrice")
        }
    }
}
