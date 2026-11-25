//
//  HowSureSection.swift
//  Atlas
//

import SwiftUI

/// How sure the suggestions are (board 73, `pr-prod-insp`): the banner's
/// level, weighted by traffic, and what it stands on by sales state.
struct HowSureSection: View {
    let viewModel: PricingViewModel

    var body: some View {
        InspectorSection(.howSure, in: viewModel.strategy) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xSmall) {
                    HowSureMeter(confidence: howSure)
                    Text(howSure.word)
                        .atlasTextStyle(.headline)
                }
                .accessibilityElement(children: .combine)
                Text(baseline)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("pricing.inspector.howSure")
        }
    }

    private var baseline: String {
        viewModel.productRoute.map { viewModel.countriesBaseline(productID: $0.productID) }
            ?? PricingSalesLine.banner(availability: .notRead, salesCountries: 0)
    }

    private var howSure: HowSure {
        viewModel.productRoute.map { viewModel.countriesHowSure(productID: $0.productID) } ?? .notVerySure
    }
}
