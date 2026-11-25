//
//  PriceTestResultDetails.swift
//  Atlas
//

import SwiftUI

/// A result's Details (board 76, `pt-ready-det`): the 90% range, the
/// sample on both sides, and what it does for the region's suggestions.
struct PriceTestResultDetails: View {
    let test: PriceTest
    let result: PriceTestResult

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            PriceTestFactRow(label: String(localized: "90% range", comment: "kind:label"), value: result.rangeText)
            PriceTestFactRow(label: String(localized: "Sample", comment: "kind:label"), value: sample)
            if result.verdict != .tooLittleData, result.excludesZero {
                Text("\(test.region.title)’s suggestions can now be Sure: the test counts as a measured change.", comment: "kind:description")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("priceTest.details.sure")
            }
        }
        .padding(Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("priceTest.details")
    }

    /// "2,140 → 2,210 page views, 96 → 130 starts".
    private var sample: String {
        let windows = result.windows
        let views = "\(PricingText.grouped(windows.testBefore.pageViews)) → \(PricingText.grouped(windows.testDuring.pageViews))"
        let starts = "\(PricingText.grouped(windows.testBefore.starts)) → \(PricingText.grouped(windows.testDuring.starts))"
        return String(localized: "\(views) page views, \(starts) starts", comment: "kind:label")
    }
}
