//
//  ReviewsScreen.swift
//  Atlas
//

import SwiftUI

/// Ratings & Reviews: the header with the translation switch, the filters,
/// the reviews with their replies, and beside them the ratings and what
/// people write about.
struct ReviewsScreen: View {
    @Bindable var viewModel: ReviewsViewModel
    let onThemeAction: (ReviewThemeSummary) -> Void
    let onUpgrade: () -> Void

    @State private var width: CGFloat = 0
    /// For Reply Automatically's next check; nil in previews.
    @Environment(BackgroundWork.self) private var background: BackgroundWork?
    @Environment(AnalyticsStore.self) private var analytics: AnalyticsStore?
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            banners
            if viewModel.hasLoaded {
                ReviewsFilterBar(viewModel: viewModel)
                HStack(alignment: .top, spacing: Spacing.large) {
                    list
                    ReviewsSidebar(viewModel: viewModel, onThemeAction: onThemeAction, onUpgrade: onUpgrade)
                        .frame(width: sidebarWidth)
                }
            } else if viewModel.errorMessage == nil {
                skeleton
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }

    /// 300 points beside the list; narrower when the window is.
    private var sidebarWidth: CGFloat {
        switch width {
        case 800...: 300
        case 620...: 260
        default: 220
        }
    }

    private var header: some View {
        SectionHeader(
            subtitle: String(localized: "What people write about \(viewModel.app.name), in every country, and your replies.")
        ) {
            // Draft Replies… is the toolbar's Autopilot (board 57).
            Toggle(isOn: Binding { viewModel.translates } set: { viewModel.setTranslates($0) }) {
                Text("Translate to \(ReviewLanguage.appLanguageName)")
                    .font(.callout)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityIdentifier("reviews.translate")
        }
    }

    @ViewBuilder
    private var banners: some View {
        if viewModel.showsAutoReplyStrip {
            AutoReplyStrip(
                rule: viewModel.autoReplyRule,
                nextCheck: background?.nextCheckAt,
                hold: viewModel.autoReplyHold,
                writeProblem: viewModel.autoReplyWriteProblem,
                historyCount: viewModel.autoReplyHistory.count,
                onPause: { viewModel.setAutoReplyPaused($0) },
                onHistory: { viewModel.isAutoReplyHistoryPresented = true },
                onSettings: { viewModel.isAutoReplySettingsPresented = true }
            )
        }
        if let message = viewModel.errorMessage, viewModel.bulkPlan == nil {
            Banner(kind: .apiError, title: String(localized: "Couldn’t read the reviews"), message: message, isInline: true) {
                Button("Try Again") {
                    Task { await viewModel.load(force: true) }
                }
            }
            .accessibilityIdentifier("reviews.error")
        }
        if let summary = versionSummary {
            AnalyticsNotice(
                tone: .warning,
                text: [stability?.headline, summary.text].compactMap(\.self).joined(separator: " "),
                primary: stability == nil ? nil : (String(localized: "Open Stability"), {
                    navigator?.openAnalytics(.stability, appID: viewModel.app.id)
                }),
                identifier: "reviews.stability"
            )
        }
        if let text = viewModel.downloadText {
            Banner(kind: .info, title: text, isInline: true) {
                ReviewLanguageDownloadButton(languages: viewModel.languagesToDownload) {
                    await viewModel.translate()
                }
            }
            .accessibilityIdentifier("reviews.download")
        }
    }

    /// Analytics says the newest version crashes more.
    private var stability: StabilityReport? {
        guard let analytics else { return nil }
        return StabilityReport.make(analytics.reports(for: viewModel.app.id), now: AnalyticsDay(analytics.now())).flatMap { $0.isWorse ? $0 : nil }
    }

    /// The version's reviews, while it crashes more or they mention crashes.
    private var versionSummary: VersionReviewsSummary? {
        let crashing = stability
        guard let summary = VersionReviewsSummary.make(viewModel.reviews, newest: crashing?.latest.version) else { return nil }
        return crashing != nil || summary.crashMentions >= 2 ? summary : nil
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                let reviews = viewModel.listedReviews
                ForEach(reviews) { review in
                    ReviewCard(review: review, viewModel: viewModel)
                }
                if reviews.isEmpty {
                    Card {
                        Text(viewModel.emptyText)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("reviews.empty")
                }
                more
            }
            .padding(.bottom, Spacing.large)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reviews.list")
    }

    /// More of what's on this Mac, then Apple's earlier reviews.
    @ViewBuilder
    private var more: some View {
        if viewModel.hiddenCount > 0 {
            Button(viewModel.showMoreTitle) { viewModel.showMore() }
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("reviews.showMore")
        } else if viewModel.canLoadMore {
            HStack(spacing: Spacing.small) {
                Button("Load Earlier Reviews") {
                    Task { await viewModel.loadMore() }
                }
                .buttonBorderShape(.capsule)
                .disabled(viewModel.isLoadingMore)
                .accessibilityIdentifier("reviews.loadMore")
                if viewModel.isLoadingMore {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private var skeleton: some View {
        HStack(alignment: .top, spacing: Spacing.large) {
            VStack(spacing: Spacing.small) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonBlock(height: 96, cornerRadius: Radius.card)
                }
            }
            .frame(maxWidth: .infinity)
            SkeletonBlock(height: 180, cornerRadius: Radius.card)
                .frame(width: sidebarWidth)
        }
        .accessibilityIdentifier("reviews.loading")
    }
}
