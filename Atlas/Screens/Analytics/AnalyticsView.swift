//
//  AnalyticsView.swift
//  Atlas
//

import SwiftUI

/// The Analytics section (README-DS §16, board 92), laid out as App
/// Information (board 88): the section's sentence over the range and
/// "Data through Nov 9", the period and the settings gear on the right;
/// under them the strip of view cards (only once there is data), one
/// notice at most, then the open view. Before the first reports the page
/// says what Analytics is doing instead.
struct AnalyticsView: View {
    @Bindable var viewModel: AnalyticsViewModel
    /// Changes of a finding's area waiting in Review & Push.
    var waitingCount: (AnalyticsFinding) -> Int = { _ in 0 }
    /// Follows an action to its section, with what the bar there says.
    var onAct: (FindingAction, String) -> Void = { _, _ in }
    /// Stability's banner buttons: the version's card and its phased
    /// release.
    var stabilityRelease: StabilityReleaseActions = .none
    /// Reads the Overview's Rating number (the App Store's average and the
    /// current version's reviews); nil leaves it out of reach.
    var loadRating: (@MainActor () async -> OverviewRating?)?
    /// Rating's blue line: Ratings & Reviews.
    var onOpenReviews: () -> Void = {}

    @State private var rating: OverviewRating?
    @State private var isRatingLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            header
            if viewModel.availability.showsStrip {
                AnalyticsTabStrip(viewModel: viewModel)
            }
            if let notice = viewModel.notice {
                AnalyticsNoticeBanner(
                    notice: notice, appName: viewModel.app.name, now: viewModel.store.now(), isChecking: viewModel.activity.isLoading
                ) { action in
                    Task { await viewModel.handle(action) }
                }
            }
            content
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .sheet(isPresented: $viewModel.isReportsPresented) {
            ReportsFromAppleSheet(viewModel: viewModel)
        }
        .task(id: viewModel.app.id) {
            guard let loadRating else {
                isRatingLoading = false
                return
            }
            rating = await loadRating()
            isRatingLoading = false
        }
    }

    private var header: some View {
        SectionHeader(
            subtitle: String(localized: "How \(viewModel.app.name) is doing, and where people drop off before paying.", comment: "kind:description · Analytics")
        ) {
            if let funnel = viewModel.funnel, viewModel.availability.showsStrip {
                HStack(spacing: Spacing.small) {
                    Text(funnel.rangeText)
                        .atlasTextStyle(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                    Button {
                        viewModel.isReportsPresented = true
                    } label: {
                        Text("Data through \(AnalyticsText.day(funnel.period.last.date))", comment: "kind:status · Analytics header")
                            .atlasTextStyle(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(viewModel.staleDays == nil ? Palette.label2 : Palette.warn)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .help(Text("Shows each Apple report and its status.", comment: "kind:tooltip"))
                    .accessibilityIdentifier("analytics.dataThrough")
                }
            }
        } trailing: {
            if viewModel.availability.showsStrip, viewModel.funnel != nil, !viewModel.availability.isNewApp {
                Picker(String(localized: "Period", comment: "kind:label"), selection: $viewModel.days) {
                    ForEach([7, 28, 90], id: \.self) { days in
                        Text("\(days) days", comment: "kind:segment · Analytics period").tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("analytics.period")
            }
            Button {
                viewModel.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(Text("Analytics Settings", comment: "kind:tooltip"))
            .accessibilityLabel(Text("Analytics Settings", comment: "kind:button"))
            .accessibilityIdentifier("analytics.settingsButton")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.availability.isBlocking {
            AnalyticsSetupContent(viewModel: viewModel)
        } else if let funnel = viewModel.funnel {
            switch viewModel.tab {
            case .overview:
                AnalyticsOverviewView(
                    viewModel: viewModel, report: funnel, rating: rating, isRatingLoading: isRatingLoading, onOpenReviews: onOpenReviews
                ) { finding, action in
                    viewModel.markActed(finding)
                    onAct(action, finding.title)
                }
            case .breakDown:
                AnalyticsBreakDownView(viewModel: viewModel, onAct: onAct)
            case .whatToTry:
                AnalyticsWhatToTryView(viewModel: viewModel, waitingCount: waitingCount) { finding, action in
                    viewModel.markActed(finding)
                    onAct(action, finding.title)
                }
            case .afterChanges:
                AnalyticsAfterChangesView(viewModel: viewModel) {
                    onAct(.pricing(territory: nil), String(localized: "Price results are in Pricing → Results, per territory."))
                }
            case .subscriptions:
                AnalyticsSubscriptionsView(viewModel: viewModel, onAct: onAct)
            case .stability:
                AnalyticsStabilityView(viewModel: viewModel, release: stabilityRelease)
            }
        }
    }
}
