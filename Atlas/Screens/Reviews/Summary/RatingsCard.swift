//
//  RatingsCard.swift
//  Atlas
//

import SwiftUI

/// The Ratings card beside the list: Apple's average and count, the
/// written reviews' stars as bars (it says they're written reviews only),
/// and the current version against before.
struct RatingsCard: View {
    let summary: RatingsSummary

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: Spacing.large) {
                VStack(spacing: 2) {
                    Text(summary.averageText)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(ReviewText.stars(Int((summary.average ?? 0).rounded())))
                        .font(.subheadline)
                        .foregroundStyle(Palette.sectionReviews)
                        .accessibilityHidden(true)
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("reviews.ratings.average")
                VStack(spacing: 3) {
                    ForEach((1...5).reversed(), id: \.self) { stars in
                        HStack(spacing: Spacing.xSmall) {
                            Text(stars, format: .number)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Palette.label2)
                                .frame(width: 8)
                            MeterBar(fraction: summary.histogram.share(stars: stars), tint: Palette.label2)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(ReviewText.starsSpoken(stars)))
                        .accessibilityValue(Text(summary.histogram.share(stars: stars), format: .percent.precision(.fractionLength(0))))
                    }
                }
            }
            Text(summary.countText)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("reviews.ratings.count")
            if let comparison = summary.comparison {
                Divider()
                comparisonLines(comparison)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.ratings")
    }

    private func comparisonLines(_ comparison: VersionRatingComparison) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Text("\(ReviewText.rating(comparison.average)) ★")
                    .font(.headline)
                    .monospacedDigit()
                Text(comparison.sinceText)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            Text(mark(comparison.outcome) + comparison.againstText)
                .font(.subheadline)
                .foregroundStyle(comparison.outcome.isLower ? Palette.warning : Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reviews.ratings.version")
    }

    private func mark(_ outcome: ComparisonOutcome) -> String {
        if outcome.isLower { return "▼ " }
        if outcome.isHigher { return "▲ " }
        return ""
    }
}
