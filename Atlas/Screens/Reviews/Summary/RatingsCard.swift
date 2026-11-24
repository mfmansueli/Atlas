//
//  RatingsCard.swift
//  Atlas
//

import SwiftUI

/// The Ratings card beside the list: Apple's average and count, the
/// written reviews' stars as bars (it says they're written reviews only),
/// how many ratings came with stars only as a split bar, and the current
/// version against before.
struct RatingsCard: View {
    let summary: RatingsSummary

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: Spacing.large) {
                VStack(spacing: 2) {
                    Text(summary.averageText)
                        .font(.title.weight(.semibold))
                        .monospacedDigit()
                    ReviewStars(rating: Int((summary.average ?? 0).rounded()), tint: Palette.sectionReviews)
                        .accessibilityHidden(true)
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("reviews.ratings.average")
                VStack(spacing: 3) {
                    ForEach((1...5).reversed(), id: \.self) { stars in
                        HStack(spacing: Spacing.xSmall) {
                            Text(stars, format: .number)
                                .font(.footnote.monospacedDigit())
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
            if let written = summary.writtenText, let starsOnly = summary.starsOnlyText {
                starsOnlySplit(written: written, starsOnly: starsOnly)
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

    /// One bar of all the ratings: the written reviews in the bars' grey,
    /// the stars-only ratings in the stars' colour, each named below.
    private func starsOnlySplit(written: String, starsOnly: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            GeometryReader { proxy in
                let gap: CGFloat = 2
                let width = max(proxy.size.width - gap, 0)
                let writtenWidth = summary.writtenShare > 0 ? min(max(width * summary.writtenShare, 4), width - 4) : 0
                HStack(spacing: writtenWidth > 0 ? gap : 0) {
                    if writtenWidth > 0 {
                        Capsule().fill(Palette.label2).frame(width: writtenWidth)
                    }
                    Capsule().fill(Palette.sectionReviews)
                }
            }
            .frame(height: 6)
            HStack(spacing: Spacing.small) {
                legend(written, tint: Palette.label2)
                Spacer(minLength: 0)
                legend(starsOnly, tint: Palette.sectionReviews)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary.starsOnlySentence ?? starsOnly))
        .accessibilityIdentifier("reviews.ratings.starsOnly")
        .help(String(localized: "Apple’s count of ratings minus the written reviews in App Store Connect.", comment: "kind:help"))
    }

    private func legend(_ text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(text)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
        }
    }

    private func comparisonLines(_ comparison: VersionRatingComparison) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Text("\(ReviewText.rating(comparison.average)) \(Image(systemName: "star.fill"))")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(comparison.sinceText)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            Label {
                Text(comparison.againstText)
            } icon: {
                if let symbol = mark(comparison.outcome) { Image(systemName: symbol) }
            }
            .font(.subheadline)
            .foregroundStyle(comparison.outcome.isLower ? Palette.warn : Palette.label2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reviews.ratings.version")
    }

    /// The arrow before "lower than before" (README-DS §13).
    private func mark(_ outcome: ComparisonOutcome) -> String? {
        if outcome.isLower { return RateStanding.worse.systemImage }
        if outcome.isHigher { return RateStanding.better.systemImage }
        return nil
    }
}
