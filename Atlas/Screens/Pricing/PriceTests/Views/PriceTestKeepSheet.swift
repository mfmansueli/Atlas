//
//  PriceTestKeepSheet.swift
//  Atlas
//

import SwiftUI

/// Keep Test Prices… after a better result (board 76, `pt-keep`): the
/// test's countries go back to the test prices as a price change, which
/// waits in Review & Push and which Results compares like any other.
struct PriceTestKeepSheet: View {
    let test: PriceTest
    let onCancel: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Keep the Test Prices in \(test.region.title)?", comment: "kind:sheet-title")
                .atlasTextStyle(.title2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(
                    "\(test.countries.count) countries go back to \(test.step.phrase), the prices of the test. They wait in Review & Push.",
                    comment: "kind:sheet-body"
                )
                .atlasTextStyle(.callout)
                .fixedSize(horizontal: false, vertical: true)
                Text(PriceTestText.examples(test.countries))
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                Text(subscribers)
                    .atlasTextStyle(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Results compares the 28 days after, like any price change.", comment: "kind:sheet-body")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button(String(localized: "Cancel", comment: "kind:button"), action: onCancel)
                    .secondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("priceTest.keep.cancel")
                Button(String(localized: "Add to Review & Push", comment: "kind:button"), action: onAdd)
                    .primaryButton(isDefault: true)
                    .accessibilityIdentifier("priceTest.keep.add")
            }
        }
        .padding(Spacing.xxLarge)
        .frame(width: Metrics.priceTestSmallSheetWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("priceTest.keepSheet")
    }

    private var subscribers: String {
        test.step.isRaise
            ? String(localized: "Existing subscribers keep what they pay; new ones pay the test price.", comment: "kind:sheet-body")
            : String(localized: "Subscribers there pay the lower price when they renew.", comment: "kind:sheet-body")
    }
}
