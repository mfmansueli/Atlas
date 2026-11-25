//
//  CountryPriceHistogramView.swift
//  Atlas
//

import Charts
import SwiftUI

/// Prices by Country as a histogram (board 73, `pr-prod-hist`): how many
/// of the countries the filters keep sit in each $5 of price in US dollars,
/// today's in system grey and the suggested ones in the assistant's fill,
/// with a dashed line at the US base price.
struct CountryPriceHistogramView: View {
    let histogram: CountryPriceHistogram

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Chart {
                ForEach(histogram.bins) { bin in
                    BarMark(
                        x: .value(String(localized: "Price in US$", comment: "kind:field-label"), bin.label),
                        y: .value(String(localized: "Countries", comment: "kind:field-label"), bin.count)
                    )
                    .foregroundStyle(by: .value(String(localized: "Prices", comment: "kind:label"), bin.series.title))
                    .position(by: .value(String(localized: "Prices", comment: "kind:label"), bin.series.title))
                }
                if let base = baseBinLabel {
                    RuleMark(x: .value(String(localized: "US base price", comment: "kind:field-label"), base))
                        .foregroundStyle(PriceLevel.histogramBaseLine)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("US base", comment: "kind:field-label")
                                .atlasTextStyle(.subheadline)
                                .foregroundStyle(Palette.label2)
                        }
                }
            }
            .chartForegroundStyleScale([
                CountryPriceHistogram.Series.now.title: PriceLevel.histogramNow,
                CountryPriceHistogram.Series.suggested.title: PriceLevel.histogramSuggested,
            ])
            .chartXAxisLabel(String(localized: "Price in US$, per $5", comment: "kind:hint"))
            .chartYAxisLabel(String(localized: "Countries", comment: "kind:field-label"))
            .chartLegend(histogram.hasSuggestions ? .visible : .hidden)
            .frame(minHeight: Metrics.countriesHistogramHeight)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Histogram of prices in US dollars", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("countries.histogram")
    }

    /// The bin the US base price falls in.
    private var baseBinLabel: String? {
        guard let base = histogram.baseDollars else { return nil }
        let lower = Int(max(0, base) / Double(CountryPriceHistogram.binWidth)) * CountryPriceHistogram.binWidth
        return histogram.bins.first { $0.lowerBound == lower }?.label
    }
}
