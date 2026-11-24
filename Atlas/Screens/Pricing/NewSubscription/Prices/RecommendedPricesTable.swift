//
//  RecommendedPricesTable.swift
//  Atlas
//

import SwiftUI

/// The countries and regions whose recommended price differs from Apple's:
/// each with its flag, Apple's price, the recommended one and the change.
/// With a `selection`, each row has a checkbox (the review sheet).
struct RecommendedPricesTable: View {
    let places: [NewSubscriptionRecommendation.Place]
    var selection: Binding<Set<String>>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            LazyVStack(spacing: 0) {
                ForEach(places) { place in
                    row(place)
                    Divider()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.recommendedPrices.table")
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            if selection != nil { Color.clear.frame(width: Metrics.tableCheckboxWidth) }
            Text(String(localized: "Country or region", comment: "kind:column-header"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(localized: "Apple’s price", comment: "kind:column-header"))
                .frame(width: Metrics.tablePriceColumnWidth, alignment: .trailing)
            Text(String(localized: "Recommended", comment: "kind:column-header"))
                .frame(width: Metrics.tablePriceColumnWidth, alignment: .trailing)
            Text(String(localized: "Change", comment: "kind:column-header"))
                .frame(width: Metrics.tableChangeColumnWidth, alignment: .trailing)
        }
        .font(.subheadline)
        .foregroundStyle(Palette.label2)
        .padding(.vertical, Spacing.xSmall)
    }

    private func row(_ place: NewSubscriptionRecommendation.Place) -> some View {
        HStack(spacing: Spacing.small) {
            if let selection {
                Toggle(isOn: Binding {
                    selection.wrappedValue.contains(place.id)
                } set: { isOn in
                    if isOn { selection.wrappedValue.insert(place.id) } else { selection.wrappedValue.remove(place.id) }
                }) {
                    Text(place.territory.name)
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: Metrics.tableCheckboxWidth)
                .accessibilityIdentifier("pricing.recommendedPrices.\(place.id).check")
            }
            HStack(spacing: Spacing.xSmall) {
                FlagTile(regionCode: place.territory.alpha2)
                Text(place.territory.name)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(place.currency.format(place.equalized))
                .foregroundStyle(Palette.label2)
                .frame(width: Metrics.tablePriceColumnWidth, alignment: .trailing)
            Text(place.currency.format(place.recommended))
                .fontWeight(.semibold)
                .frame(width: Metrics.tablePriceColumnWidth, alignment: .trailing)
            Text(place.changeText)
                .foregroundStyle(place.isLower ? Palette.decrease : Palette.increase)
                .frame(width: Metrics.tableChangeColumnWidth, alignment: .trailing)
        }
        .font(.callout.monospacedDigit())
        .padding(.vertical, Spacing.xSmall)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pricing.recommendedPrices.\(place.id)")
    }
}
