//
//  NominationsGallery.swift
//  Atlas
//

import SwiftUI

/// The nominations that include the app, grouped Drafts → Submitted →
/// Archived, with an assistant's new nominations at the top of Drafts and
/// the safety line under them.
struct NominationsGallery: View {
    @Bindable var viewModel: NominationsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                ForEach(NominationState.allCases, id: \.self) { state in
                    group(state)
                }
                Text("Atlas shows the nominations that include \(viewModel.app.name). Apple doesn’t say which ones get featured. Nothing is sent until you push.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("nominations.footnote")
            }
            .padding(.bottom, Spacing.xxLarge)
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("nominations.gallery")
    }

    private func group(_ state: NominationState) -> some View {
        let nominations = viewModel.nominations(in: state)
        let proposals = state == .draft ? viewModel.newProposals : []
        return VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.xSmall) {
                Text(state.groupTitle)
                    .font(.headline)
                Text(nominations.count, format: .number)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .accessibilityElement(children: .combine)
            if nominations.isEmpty, proposals.isEmpty {
                Text(state.emptyText)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: Spacing.medium, alignment: .top)], spacing: Spacing.medium) {
                ForEach(proposals) { proposal in
                    NominationProposalCard(
                        proposal: proposal,
                        onReview: { viewModel.openProposal(proposal.id) },
                        onDismiss: { viewModel.dismissProposal(proposal.id) }
                    )
                }
                ForEach(nominations) { nomination in
                    NominationCard(
                        nomination: nomination,
                        apps: viewModel.appsText(nomination),
                        need: viewModel.need(nomination),
                        isQueued: !viewModel.queued(nomination.id).isEmpty && nomination.state != .archived
                    ) {
                        viewModel.open(nomination.id)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nominations.group.\(state.rawValue.lowercased())")
    }
}
