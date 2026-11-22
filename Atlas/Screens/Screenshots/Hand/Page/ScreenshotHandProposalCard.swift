//
//  ScreenshotHandProposalCard.swift
//  Atlas
//

import SwiftUI

/// A file an assistant suggested for a screenshot: which one, who and why,
/// the file small, with Dismiss and Accept.
struct ScreenshotHandProposalCard: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let proposal: ScreenshotHandProposal

    @State private var image: CGImage?

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            Group {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                } else {
                    Palette.fill2
                }
            }
            .frame(width: 54, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(viewModel.handProposalTitle(proposal))
                    .font(.headline)
                HStack(spacing: Spacing.xSmall) {
                    Pill(text: String(localized: "Suggested"), style: .machineTranslated)
                        .fixedSize()
                    AssistantChip(name: proposal.client)
                    Text(proposal.file.fileName)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(proposal.reason)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.xSmall) {
                    Spacer()
                    Button("Dismiss") { Task { await viewModel.dismissHandProposal(proposal) } }
                        .accessibilityIdentifier("screenshots.hand.proposal.dismiss")
                    Button("Accept") { Task { await viewModel.acceptHandProposal(proposal) } }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("screenshots.hand.proposal.accept")
                }
                .controlSize(.small)
            }
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .task(id: proposal.file.id) {
            let folder = viewModel.services.handFiles
            let file = proposal.file
            let appID = viewModel.app.id
            image = await Task.detached(priority: .userInitiated) { folder.image(for: file, appID: appID, pixelWidth: 160) }.value
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.hand.proposal")
    }
}
