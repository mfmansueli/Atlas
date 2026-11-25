//
//  CountrySuggestedPriceDetail.swift
//  Atlas
//

import SwiftUI

/// Under the popover's Suggested price: a −/+ stepper over the country's
/// price points with the change pill and US dollars, then why ("At R$ 129,90
/// it feels like $43 for local incomes, 1.1× the US price; you get ≈ $20.",
/// "Why: R$ 249,90 feels like 2.1× the US price there.") and what it's
/// based on ("World Bank PPP price level · factor 0.56 · Not very sure"),
/// or "Adjusted from R$ 129,90" once stepped.
struct CountrySuggestedPriceDetail: View {
    let row: CountryPriceRow
    let price: Decimal
    /// "US", for "1.1× the US price".
    let baseName: String
    /// What `price` earns, from its point; nil when the point isn't here.
    let proceeds: Decimal?
    let isAdjusted: Bool
    let onStep: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Stepper {
                    Text(row.currency.format(price))
                        .atlasTextStyle(.headline)
                        .foregroundStyle(Palette.ai)
                        .monospacedDigit()
                } onIncrement: {
                    onStep(1)
                } onDecrement: {
                    onStep(-1)
                }
                .accessibilityLabel(Text("Suggested price", comment: "kind:accessibility-label"))
                .accessibilityValue(Text(row.currency.format(price)))
                .accessibilityIdentifier("countries.popover.stepper")
                PriceChangePill(change: PriceChange(old: row.current.customerPrice, new: price))
                Spacer(minLength: 0)
                Text(CountryPriceRow.dollarsText(row.dollars(price)))
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
            }
            if let feels = row.feelsLike {
                Text(feelsText(feels))
                    .atlasTextStyle(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    "Why: \(row.currency.format(row.current.customerPrice)) feels like \(feels.ratioText(row.current.customerPrice)) the \(baseName) price there.",
                    comment: "kind:sheet-body"
                )
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
            basisLine
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.popover.why")
    }

    /// "At R$ 129,90 it feels like $43 for local incomes, 1.1× the US
    /// price; you get ≈ $20."
    private func feelsText(_ feels: CountryFeelsLike) -> String {
        let shown = row.currency.format(price)
        let value = feels.valueText(price)
        let ratio = feels.ratioText(price)
        guard let proceeds, let dollars = row.dollars(proceeds) else {
            return String(localized: "At \(shown) it feels like \(value) for local incomes, \(ratio) the \(baseName) price.", comment: "kind:sheet-body")
        }
        let earned = CountryPriceRow.dollarsText(dollars)
        return String(
            localized: "At \(shown) it feels like \(value) for local incomes, \(ratio) the \(baseName) price; you get \(earned).",
            comment: "kind:sheet-body"
        )
    }

    @ViewBuilder
    private var basisLine: some View {
        if isAdjusted, let suggested = row.suggested {
            Text("Adjusted from \(row.currency.format(suggested.customerPrice))", comment: "kind:hint")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("countries.popover.adjusted")
        } else {
            HStack(spacing: Spacing.xSmall) {
                Text(basisText)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                if let howSure = row.confidence?.howSure {
                    HowSureMeter(confidence: howSure)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// "World Bank PPP price level · factor 0.56 · Not very sure".
    private var basisText: String {
        var parts: [String] = []
        if let provenance = row.provenance {
            parts.append(provenance.source?.name ?? provenance.badge)
        }
        if let factor = row.factor {
            parts.append(String(localized: "factor \(factor.fixed(2))", comment: "kind:hint"))
        }
        if let howSure = row.confidence?.howSure {
            parts.append(howSure.word)
        }
        return parts.joined(separator: " · ")
    }
}
