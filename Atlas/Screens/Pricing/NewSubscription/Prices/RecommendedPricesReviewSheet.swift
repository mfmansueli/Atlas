//
//  RecommendedPricesReviewSheet.swift
//  Atlas
//

import SwiftUI

/// Review… on a new subscription added with Apple's prices and the
/// recommendations for later (board 18, "Reviewing the recommendations
/// later", in README-DS's look): every country or region whose recommended
/// price differs, each with a checkbox, a "30% or more lower" filter, and
/// Apply Selected, Apply All, Keep Apple's Prices or Later.
struct RecommendedPricesReviewSheet: View {
    let productName: String
    let places: [NewSubscriptionRecommendation.Place]
    let onApply: ([String]) -> Void
    let onKeep: () -> Void
    let onLater: () -> Void

    @State private var selection: Set<String>
    @State private var onlyMuchLower = false

    /// The filter's line: 30% or more below Apple's price.
    static let muchLower = Decimal(string: "-0.3") ?? 0

    init(
        productName: String,
        places: [NewSubscriptionRecommendation.Place],
        onApply: @escaping ([String]) -> Void,
        onKeep: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) {
        self.productName = productName
        self.places = places
        self.onApply = onApply
        self.onKeep = onKeep
        self.onLater = onLater
        _selection = State(initialValue: Set(places.map(\.id)))
    }

    private var shown: [NewSubscriptionRecommendation.Place] {
        onlyMuchLower ? places.filter { $0.change <= Self.muchLower } : places
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(String(localized: "Review recommended prices", comment: "kind:sheet-title"))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(String(
                    localized: "\(productName) has Apple’s prices. Pick the countries that get the recommended price.",
                    comment: "kind:sheet-body"
                ))
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            HStack(spacing: Spacing.small) {
                Toggle(String(localized: "30% or more lower", comment: "kind:toggle"), isOn: $onlyMuchLower)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("pricing.recommendedPrices.muchLower")
                Spacer()
                Text(String(localized: "\(selection.count) of \(places.count) selected", comment: "kind:status"))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("pricing.recommendedPrices.selectedCount")
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.bottom, Spacing.small)
            ScrollView {
                RecommendedPricesTable(places: shown, selection: $selection)
                    .padding(.horizontal, Spacing.xLarge)
            }
            Divider()
            HStack(spacing: Spacing.small) {
                Button(String(localized: "Keep Apple’s Prices", comment: "kind:button"), action: onKeep)
                    .secondaryButton()
                    .accessibilityIdentifier("pricing.recommendedPrices.keep")
                Spacer()
                Button(String(localized: "Later", comment: "kind:button"), action: onLater)
                    .secondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pricing.recommendedPrices.later")
                Button(String(localized: "Apply All \(places.count)", comment: "kind:button")) {
                    onApply(places.map(\.id))
                }
                .secondaryButton()
                .accessibilityIdentifier("pricing.recommendedPrices.applyAll")
                Button(String(localized: "Apply Selected (\(selection.count))", comment: "kind:button")) {
                    onApply(places.map(\.id).filter(selection.contains))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
                .accessibilityIdentifier("pricing.recommendedPrices.applySelected")
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .frame(width: 620)
        .frame(minHeight: 420, idealHeight: 600, maxHeight: 700)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.recommendedPrices.review")
    }
}
