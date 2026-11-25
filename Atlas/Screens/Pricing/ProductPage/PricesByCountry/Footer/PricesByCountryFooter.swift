//
//  PricesByCountryFooter.swift
//  Atlas
//

import SwiftUI

/// Under the table (board 73, `pr-prod-start`): "175 countries and regions
/// · 12 likely held back by price · 3 not pushed", where the exchange
/// rates come from (board 76: here and in Details, never in the banner),
/// and when the price changes start: Right Away, or On a Date… (the
/// subscription price's `startDate`). An in-app purchase's change starts
/// right away.
struct PricesByCountryFooter: View {
    let totals: PricesByCountryTotals
    let schedule: PriceSchedule
    let canSchedule: Bool
    let onRightAway: () -> Void
    let onDate: () -> Void
    /// "Rates by ExchangeRate-API · 25 Nov 2026", linked to the provider.
    var rates: ExchangeRates = .current

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.medium) {
                totalsText
                ratesText
                Spacer(minLength: Spacing.small)
                start
            }
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.medium) {
                    totalsText
                    Spacer(minLength: Spacing.small)
                    start
                }
                ratesText
            }
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                totalsText
                ratesText
                start
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.footer")
    }

    private var totalsText: some View {
        Text(totals.text)
            .atlasTextStyle(.subheadline)
            .foregroundStyle(Palette.label2)
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityIdentifier("countries.footer.totals")
    }

    @ViewBuilder private var ratesText: some View {
        if let url = rates.source.url {
            Link(destination: url) {
                Text(rates.sourceLine)
                    .atlasTextStyle(.subheadline)
                    .lineLimit(1)
            }
            .fixedSize()
            .accessibilityIdentifier("countries.footer.rates")
        } else {
            Text(rates.sourceLine)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("countries.footer.rates")
        }
    }

    private var start: some View {
        HStack(spacing: Spacing.xxSmall) {
            Text("Price changes start:", comment: "kind:field-label")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
            Menu {
                Button(String(localized: "Right Away", comment: "kind:menu-item"), action: onRightAway)
                    .accessibilityIdentifier("countries.start.now")
                Button(String(localized: "On a Date…", comment: "kind:menu-item"), action: onDate)
                    .accessibilityIdentifier("countries.start.date")
            } label: {
                Text(startTitle)
                    .atlasTextStyle(.subheadline)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .disabled(!canSchedule)
            .help(canSchedule
                ? Text("When this product’s price changes take effect", comment: "kind:tooltip")
                : Text("In-app purchase prices change as soon as you push.", comment: "kind:tooltip"))
            .accessibilityIdentifier("countries.start")
        }
        .fixedSize()
    }

    private var startTitle: String {
        schedule.startDate.map { PricingText.date($0) } ?? String(localized: "Right Away", comment: "kind:menu-item")
    }
}
