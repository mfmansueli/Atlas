//
//  ReviewsOverviewCard.swift
//  Atlas
//

import SwiftUI

/// Ratings & Reviews on the overview: how many reviews need a reply and in
/// how many languages, how the current version is doing against before,
/// and the most mentioned subject with Reply to All.
struct ReviewsOverviewCard: View {
    let archive: ReviewsArchive
    /// Suggested replies and the groups are Pro.
    let isPro: Bool
    let onOpen: () -> Void
    let onReplyToAll: () -> Void

    var body: some View {
        Card {
            OverviewCardTitle(title: String(localized: "Ratings & Reviews"), systemImage: AppWorkspaceSection.reviews.systemImage)
            if archive.fetchedAt == nil {
                Text("Not read yet")
                    .font(.title3.weight(.semibold))
                Text("What people write about the app, in every country, and your replies.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            } else {
                Text(Self.needText(archive))
                    .font(.callout.weight(.semibold))
                    .accessibilityIdentifier("overview.reviewsCard.need")
                if let suggested = Self.suggestedText(archive, isPro: isPro) {
                    Text(suggested)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                if let comparison = VersionRatingComparison.make(reviews: archive.reviews, version: archive.currentVersion) {
                    Text("\(ReviewText.rating(comparison.average)) ★ since \(comparison.version) · \(ReviewText.rating(comparison.earlierAverage)) ★ before")
                        .font(.subheadline)
                        .foregroundStyle(comparison.outcome.isLower ? Palette.warning : Palette.label2)
                }
                if isPro, let top = Self.topTheme(archive) {
                    // Not an `OverviewRow`: that reads as one element, and
                    // this line has a button of its own.
                    VStack(spacing: 0) {
                        Divider()
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                            Text("\(top.theme.title) · \(top.countText)")
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if top.theme.action == .replyToAll, top.replyCount > 0 {
                                Button("Reply to All…", action: onReplyToAll)
                                    .buttonStyle(.link)
                                    .controlSize(.small)
                                    .accessibilityIdentifier("overview.reviewsCard.replyToAll")
                            }
                        }
                        .font(.callout)
                        .padding(.vertical, 5)
                    }
                }
            }
            Button("Open Reviews", action: onOpen)
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("overview.reviewsCard.open")
        }
        .accessibilityIdentifier("overview.reviewsCard")
    }

    /// "24 reviews need a reply, in 9 languages."
    static func needText(_ archive: ReviewsArchive) -> String {
        let count = archive.needsReplyCount
        guard count > 0 else { return String(localized: "Every review that needs a reply has one.") }
        let languages = archive.needsReplyLanguageCount
        let reviews = count == 1 ? String(localized: "1 review needs a reply") : String(localized: "\(ReviewText.count(count)) reviews need a reply")
        return languages > 1 ? String(localized: "\(reviews), in \(ReviewText.languages(languages)).") : "\(reviews)."
    }

    /// "Replies are suggested for 6 of them, each in the reviewer’s language."
    static func suggestedText(_ archive: ReviewsArchive, isPro: Bool) -> String? {
        let count = isPro ? archive.openSuggestionCount : 0
        guard count > 0 else { return nil }
        return count == 1
            ? String(localized: "A reply is suggested for 1 of them, in the reviewer’s language.")
            : String(localized: "Replies are suggested for \(count) of them, each in the reviewer’s language.")
    }

    /// The group with the most reviews that isn't praise.
    static func topTheme(_ archive: ReviewsArchive) -> ReviewThemeSummary? {
        archive.themes
            .filter { $0.action != .suggestStorePage }
            .map { ReviewThemeSummary.make($0, reviews: archive.reviews) }
            .max { $0.count < $1.count }
    }
}
