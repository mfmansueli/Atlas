//
//  ReviewsSidebar.swift
//  Atlas
//

import SwiftUI

/// Beside the list: the Ratings card, then "What people write about":
/// the groups with their actions in Pro, what Pro adds in Free.
struct ReviewsSidebar: View {
    @Bindable var viewModel: ReviewsViewModel
    let onThemeAction: (ReviewThemeSummary) -> Void
    let onUpgrade: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                RatingsCard(summary: viewModel.ratingsSummary)
                HStack(spacing: Spacing.small) {
                    Text("What people write about")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                    if viewModel.isPro, let source = viewModel.suggestionSource {
                        SuggestionSourceTag(source: .assistant(client: source))
                    }
                }
                .padding(.top, Spacing.xxSmall)
                themes
            }
            .padding(.bottom, Spacing.large)
        }
        .scrollIndicators(.never)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.sidebar")
    }

    @ViewBuilder
    private var themes: some View {
        let summaries = viewModel.themeSummaries
        if !viewModel.isPro {
            Card(padding: Spacing.medium) {
                Text("""
                Pro reads every review in every language and groups them: what’s broken, what people ask for, what they love. Each \
                group ends in something to do.
                """)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                Button("Upgrade to Pro…", action: onUpgrade)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("reviews.themes.upgrade")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reviews.themes.locked")
        } else if summaries.isEmpty {
            Card(padding: Spacing.medium) {
                Text("No groups yet. Your assistant reads the reviews in every language and groups them by subject, each with something to do.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ReviewsAskButton(app: viewModel.app)
                    .controlSize(.regular)
                    .buttonBorderShape(.capsule)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reviews.themes.empty")
        } else {
            ForEach(summaries) { summary in
                ReviewThemeCard(summary: summary) { onThemeAction(summary) }
            }
        }
    }
}
