//
//  ScreenshotHandProposalCard.swift
//  Atlas
//

import SwiftUI

/// A file an assistant suggested for a screenshot: which one, who and why,
/// the file small, with Dismiss and Accept. It arrives and settles like
/// any suggestion (effects 2 and 5).
struct ScreenshotHandProposalCard: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let proposal: ScreenshotHandProposal

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: CGImage?
    @State private var isSettling = false

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
            .clipShape(RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(spacing: Spacing.xSmall) {
                    Text(viewModel.handProposalTitle(proposal))
                        .font(.body.weight(.semibold))
                    if let confidence = proposal.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
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
                    Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion) { Task.immediate { await viewModel.dismissHandProposal(proposal) } } }
                        .accessibilityIdentifier("screenshots.hand.proposal.dismiss")
                    Button("Accept", action: accept)
                        .rowActionButton()
                        .accessibilityIdentifier("screenshots.hand.proposal.accept")
                }
                .controlSize(.regular)
                if let details = proposal.layers?.details { SuggestionDetailsDisclosure(details: details) }
            }
        }
        .padding(Spacing.medium)
        .suggestionSurface(isSettling: isSettling, arrivalKey: proposal.id, arrivedAt: proposal.receivedAt, cornerRadius: Radius.card)
        .task(id: proposal.file.id) {
            let folder = viewModel.services.handFiles
            let file = proposal.file
            let appID = viewModel.app.id
            image = await Task.detached(priority: .userInitiated) { folder.image(for: file, appID: appID, pixelWidth: 160) }.value
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.hand.proposal")
    }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            Task.immediate { await viewModel.acceptHandProposal(proposal) }
        }
    }
}
