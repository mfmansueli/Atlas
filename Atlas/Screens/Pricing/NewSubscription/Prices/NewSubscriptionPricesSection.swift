//
//  NewSubscriptionPricesSection.swift
//  Atlas
//

import SwiftUI

/// Create Subscription's prices in the other countries and regions
/// (board 18): the recommended prices, with how many are lower, a few of
/// them and the table on demand; Apple's prices now with the
/// recommendations for later; or Apple's automatic prices.
struct NewSubscriptionPricesSection: View {
    @Binding var choice: NewSubscriptionPriceChoice
    /// For the US price typed so far; nil without one.
    let recommendation: NewSubscriptionRecommendation?
    /// Free: the recommended prices carry the PRO chip.
    let isFree: Bool

    @State private var showsCountries = false

    var body: some View {
        Section {
            ForEach(NewSubscriptionPriceChoice.allCases) { option in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                    RadioRow(title: option.title, detail: option.detail, isSelected: choice == option) {
                        choice = option
                    }
                    if option == .recommended {
                        Pill(text: String(localized: "Recommended", comment: "kind:pill"), style: .accent)
                        if isFree { ProChip() }
                    }
                }
                .accessibilityIdentifier("pricing.newSubscription.prices.\(option.rawValue)")
            }
            if choice == .recommended {
                recommendedDetail
            }
        } header: {
            Text(String(localized: "Prices in the other \(TerritoryCatalog.standard.territories.count - 1) countries and regions", comment: "kind:section-title"))
        } footer: {
            note("Prices you set yourself don’t follow Apple’s automatic updates for taxes and exchange rates.")
        }
    }

    /// How many recommended prices are lower, a few of them, and the table.
    @ViewBuilder
    private var recommendedDetail: some View {
        if let recommendation, !recommendation.changed.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(recommendation.summary)
                    .font(.callout)
                    .accessibilityIdentifier("pricing.newSubscription.prices.summary")
                Text(recommendation.samplesText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                if !recommendation.usesAppleRatios {
                    note("Estimated from each currency’s usual exchange. The push uses Apple’s own price points.")
                }
                Button(showsCountries
                    ? String(localized: "Hide Countries", comment: "kind:button")
                    : String(localized: "Show \(recommendation.changed.count) Countries", comment: "kind:button"))
                {
                    showsCountries.toggle()
                }
                .plainButton()
                .accessibilityIdentifier("pricing.newSubscription.prices.showCountries")
                if showsCountries {
                    RecommendedPricesTable(places: recommendation.changed)
                }
            }
        } else if recommendation != nil {
            note("At this price the recommended prices are Apple’s automatic ones.")
        } else {
            note("Enter the US price to see the recommended prices.")
        }
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
