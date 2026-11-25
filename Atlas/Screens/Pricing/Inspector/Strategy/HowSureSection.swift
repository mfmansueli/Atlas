//
//  HowSureSection.swift
//  Atlas
//

import SwiftUI

/// How sure the suggestions are (board 73, `pr-prod-insp`): purchasing
/// power alone is Not very sure until Atlas reads sales.
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
                Text(PricesByCountrySuggestionBanner.baseline)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("pricing.inspector.howSure")
        }
    }

    private var howSure: HowSure {
        viewModel.productRoute.map { viewModel.countriesHowSure(productID: $0.productID) } ?? .notVerySure
    }
}
