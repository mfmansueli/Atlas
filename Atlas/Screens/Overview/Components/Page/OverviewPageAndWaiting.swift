//
//  OverviewPageAndWaiting.swift
//  Atlas
//

import SwiftUI

/// The Overview (README — redesign, November 22: "Overview is three
/// lists"): what the version still needs, the suggestions to review per
/// section and After release on the left; the App Store page, smaller, on
/// the right. One above the other when the window is narrow, the lists
/// first (`SideColumnLayout`).
struct OverviewPageAndWaiting<Lead: View, VersionNotice: View>: View {
    let app: StoreApp
    /// For the preview's screenshots and the captions waiting.
    let services: any StorePageServices
    let content: StorePageContent?
    let storePage: StorePageSummary?
    let newLanguages: NewLanguagesSummary?
    /// The version on its way to the App Store; its card leads the column.
    var release: ReleaseViewModel?
    /// Analytics, Ratings & Reviews and Product Pages.
    let afterRelease: [OverviewAfterReleaseRow]
    /// Above the lists: the assistant's card, and the stability alert
    /// while the version card doesn't follow a submitted version.
    @ViewBuilder var lead: () -> Lead
    /// In the version card, under its steps once submitted: the stability
    /// alert (Redesign, 24 November).
    @ViewBuilder var versionNotice: () -> VersionNotice

    @Environment(AppSummaryStore.self) private var summaries
    @Environment(ChangeQueue.self) private var changes
    @Environment(PricingModeStore.self) private var pricingModes
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(FieldSuggestionStore.self) private var suggestions

    /// The preview's column.
    static var previewWidth: CGFloat { 300 }
    /// The lists' least width beside the preview; narrower, the preview
    /// goes under them.
    static var minimumListsWidth: CGFloat { 380 }

    /// The lists, then the preview beside them or under them. It decides
    /// from the width it's offered: one measured after the fact never went
    /// under the side-by-side minimum, which kept the window's content
    /// wider than the window, centred and clipped (the sidebar cut on its
    /// left, Review & Push in the toolbar's overflow menu).
    static var columns: SideColumnLayout {
        SideColumnLayout(
            sideWidth: previewWidth, minimumMainWidth: minimumListsWidth, spacing: Spacing.xxLarge,
            stacksSideBelow: true, stackedSpacing: Spacing.large
        )
    }

    var body: some View {
        Self.columns {
            VStack(alignment: .leading, spacing: Spacing.large) {
                lead()
                if let release, release.phase != nil {
                    VersionCard(viewModel: release) {
                        navigator.isSubmitPresented = true
                    } onOpenEvent: { eventID in
                        navigator.open(.inAppEvents, intent: .showInAppEvents(eventID: eventID))
                    } onOpenReviewInformation: {
                        navigator.open(.appInformation, intent: .openAppInformationPage(.appReview))
                    } onSeeReviews: {
                        navigator.open(.reviews)
                    } notice: {
                        versionNotice()
                    }
                }
                OverviewWaitingCard(rows: OverviewWaitingSection.rows(waitingFacts), onOpen: open)
                OverviewAfterReleaseCard(rows: afterRelease, onOpen: openAfterRelease)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let content {
                OverviewStorePreview(app: app, content: content, screenshots: services.screenshots, links: previewLinks)
            }
        }
    }

    private var badgeCounts: SectionBadgeCounts {
        SectionBadgeCounts(
            appID: app.id,
            suggestions: suggestions,
            screenshots: services.screenshots.documentCenter,
            pricing: SectionBadgeCounts.pricingCount(appID: app.id, summaries: summaries, modes: pricingModes, changes: changes)
        )
    }

    private var waitingFacts: OverviewWaitingSection.Facts {
        let storeLanguages = Set(suggestions.toReview(for: app.id, area: .storePage).compactMap { suggestion -> String? in
            guard case let .storePage(code) = suggestion.target.scope else { return nil }
            return code
        })
        let pending = Set((newLanguages?.pending ?? []).map(\.code))
        let pages = Set(suggestions.toReview(for: app.id, area: .appInformation).compactMap(\.target.scope.page))
        let captions = services.screenshots.documentCenter?.openProposedCaptions(appID: app.id) ?? []
        return OverviewWaitingSection.Facts(
            counts: badgeCounts,
            storePageLanguages: storeLanguages.count,
            newPages: storeLanguages.intersection(pending).count,
            captionLanguages: Set(captions.map(\.locale)).count,
            isPricingEstimate: summaries.pricingSuggestionCounts[app.id] == nil,
            informationPages: AppInformationPage.allCases.filter(pages.contains).map(\.title)
        )
    }

    private var previewLinks: AppStorePreviewLinks {
        let counts = badgeCounts
        func link(_ section: AppWorkspaceSection) -> AppStorePreviewLink {
            AppStorePreviewLink(title: section.title, count: counts.count(for: section)) { open(section) }
        }
        return AppStorePreviewLinks(
            storePage: link(.storePage),
            appInformation: link(.appInformation),
            screenshots: link(.screenshots),
            pricing: link(.subscriptionPricing)
        )
    }

    /// Review (or Open) on a row, or a tag on the preview: the section, on
    /// its first suggestion when it has some.
    private func open(_ section: AppWorkspaceSection) {
        let hasSuggestions = badgeCounts.count(for: section) > 0
        switch section {
        case .storePage where hasSuggestions:
            navigator.open(.storePage, intent: .reviewFieldSuggestions(.storePage))
        case .appInformation where hasSuggestions:
            navigator.open(.appInformation, intent: .reviewFieldSuggestions(.appInformation))
        case .subscriptionPricing where hasSuggestions:
            navigator.open(.subscriptionPricing, intent: .reviewSuggestions)
        default:
            navigator.open(section)
        }
    }

    /// Open on an After release row: Product Pages opens on its list.
    private func openAfterRelease(_ section: AppWorkspaceSection) {
        switch section {
        case .productPages: navigator.open(.productPages, intent: .showProductPage(name: nil))
        default: navigator.open(section)
        }
    }
}
