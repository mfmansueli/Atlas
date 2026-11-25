//
//  NominationsScreen.swift
//  Atlas
//

import SwiftUI

/// Nominations (board 70): the gallery, or one nomination's page in its
/// place (a draft to edit, an assistant's nomination to review, or a
/// submitted one to read), under the section's one banner.
struct NominationsScreen: View {
    @Bindable var viewModel: NominationsViewModel
    let actions: Actions

    @State private var width: CGFloat = 1000

    /// Under this, the small window (860 × 560 without the sidebar): one
    /// column, type options stacked, secondary buttons tucked away.
    static let compactWidth: CGFloat = 900

    /// What leaves the section: Settings, Review & Push, In-App Events.
    struct Actions {
        var changeKey: () -> Void = {}
        var openReviewPush: () -> Void = {}
        var openEvents: () -> Void = {}
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if let proposal = viewModel.selectedProposal {
                NominationPageHeader(viewModel: viewModel, title: proposal.content.trimmedName, proposal: proposal, actions: actions, isCompact: isCompact)
                page { NominationPage(viewModel: viewModel, target: .proposal(proposal), actions: actions, isCompact: isCompact) }
            } else if let nomination = viewModel.selectedNomination {
                NominationPageHeader(viewModel: viewModel, title: nomination.displayName, nomination: nomination, actions: actions, isCompact: isCompact)
                page {
                    if nomination.isEditable {
                        NominationPage(viewModel: viewModel, target: .nomination(nomination), actions: actions, isCompact: isCompact)
                    } else {
                        NominationReadOnlyPage(viewModel: viewModel, nomination: nomination, actions: actions)
                    }
                }
            } else {
                galleryHeader
                NominationsBanner(viewModel: viewModel, nominationID: nil, actions: actions)
                gallery
            }
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var isCompact: Bool { width < Self.compactWidth }

    /// One nomination's page: one column, at most 780 pt wide.
    private func page(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: NominationPage.maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.xxLarge)
        }
        .leavesChatRoom()
        .scrollContentBackground(.hidden)
    }

    private var galleryHeader: some View {
        // New Nomination… is the toolbar's page action (board 80).
        SectionHeader(subtitle: String(localized: "Tell Apple’s editors about launches, updates and events, weeks ahead.", comment: "kind:description")) {}
    }

    @ViewBuilder
    private var gallery: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: Spacing.medium) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(height: Metrics.skeletonRowCardHeight, lines: 2)
                }
            }
            .loadingSkeleton(LoadingCopy.nominations, identifier: "nominations.loading")
        case let .failed(message):
            Banner(kind: .apiError, title: String(localized: "Couldn’t read the nominations", comment: "kind:banner"), message: message, isInline: true) {
                Button("Try Again") {
                    Task { await viewModel.load(force: true) }
                }
            }
            .accessibilityIdentifier("nominations.error.load")
            Spacer(minLength: 0)
        case .loaded:
            if viewModel.isEmpty {
                NominationsEmptyState()
            } else {
                NominationsGallery(viewModel: viewModel)
            }
        }
    }
}
