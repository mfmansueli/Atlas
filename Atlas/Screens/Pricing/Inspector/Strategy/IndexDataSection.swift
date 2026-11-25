//
//  IndexDataSection.swift
//  Atlas
//

import SwiftUI

/// How fresh the index data and exchange rates are, with “Update Index Data”.
struct IndexDataSection: View {
    let viewModel: PricingViewModel

    var body: some View {
        let model = viewModel.strategy
        InspectorSection(.indexData, in: model) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(PriceIndexSource.allCases) { source in
                    if let index = model.index(source) {
                        HStack(spacing: Spacing.xSmall) {
                            Text(source.name).atlasTextStyle(.callout)
                            Spacer(minLength: Spacing.xSmall)
                            Text(index.edition.label)
                                .atlasTextStyle(.subheadline)
                                .foregroundStyle(Palette.label2)
                                .lineLimit(1)
                            if index.edition.isStale(asOf: .now) {
                                Pill(text: String(localized: "Older than a year"), style: .warning)
                            }
                        }
                        .help(Self.indexDetail(index))
                        .accessibilityElement(children: .combine)
                    }
                }
                Text(Self.snapshotLine(model.snapshot))
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                exchangeRates
                Button("Update Index Data") { model.updateIndexData() }
                    .controlSize(.regular)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("pricing.updateIndexData")
                if let message = model.updateMessage {
                    Text(message)
                        .atlasTextStyle(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// "Exchange rates of 25 Nov 2026 · Rates by ExchangeRate-API", linked
    /// to the provider as its terms ask.
    @ViewBuilder private var exchangeRates: some View {
        let rates = ExchangeRates.current
        if let url = rates.source.url {
            Link(destination: url) {
                Text(rates.detailText)
                    .atlasTextStyle(.subheadline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("pricing.exchangeRates")
        } else {
            Text(rates.detailText)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pricing.exchangeRates")
        }
    }

    /// "Bundled snapshot from 25 Nov 2026 · works offline", with
    /// "· approximate" for the sample.
    static func snapshotLine(_ snapshot: PriceIndexSnapshot) -> String {
        let date = PricingText.date(snapshot.snapshotDate)
        let line = String(localized: "Bundled snapshot from \(date) · works offline", comment: "kind:hint")
        return snapshot.isApproximate ? line + String(localized: " · approximate", comment: "kind:hint") : line
    }

    /// "2025 data · 17 from an older year or other figures", the row's help.
    static func indexDetail(_ index: PriceIndex) -> String {
        var parts = [index.edition.dataYear.map { String(localized: "\(String($0)) data", comment: "kind:hint") } ?? index.edition.label]
        let fallbacks = index.fallbackCount
        if fallbacks > 0 {
            parts.append(String(localized: "\(fallbacks) from an older year or other figures", comment: "kind:hint"))
        }
        return parts.joined(separator: " · ")
    }
}
