//
//  InAppEventMediaCard.swift
//  Atlas
//

import SwiftUI

/// The art an assistant proposed for the event, by kind (the card, 16:9,
/// and the details page's top, 9:16), as the App Store shows it, with
/// Accept and Dismiss. The editor shows it under the media strip only
/// while there are proposals. "Ask Claude Code…" has more art made.
struct InAppEventMediaCard: View {
    let event: InAppEvent
    var app: StoreApp?
    var proposals: [InAppEventArtworkProposal] = []
    var overlayTexts: (InAppEventArtworkProposal) -> InAppEventArtworkOverlayTexts = { proposal in
        InAppEventArtworkOverlayTexts(locale: proposal.locales.first ?? "en-US", isRightToLeft: false, badge: "", name: "", description: "", appName: "")
    }

    var onAccept: (InAppEventArtworkProposal) -> Void = { _ in }
    var onDismiss: (InAppEventArtworkProposal) -> Void = { _ in }

    var body: some View {
        Card {
            HStack(spacing: Spacing.small) {
                Text("Suggested images and video")
                    .font(.body.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let app, !event.state.isOver {
                    InAppEventArtworkAskButton(app: app, event: event)
                        .controlSize(.regular)
                }
            }
            ForEach(InAppEventMedia.Kind.allCases.filter { kind in proposals.contains { $0.kind == kind } }, id: \.self) { kind in
                VStack(alignment: .leading, spacing: Spacing.small) {
                    row(kind)
                    ForEach(proposals.filter { $0.kind == kind }) { proposal in
                        proposalView(proposal)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.media")
    }

    private func row(_ kind: InAppEventMedia.Kind) -> some View {
        HStack(spacing: Spacing.small) {
            StatusMark(isOK: event.media(kind) != nil)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.callout.weight(.semibold))
                Text(kind.detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(InAppEventsViewModel.mediaText(kind, of: event))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("events.media.\(kind.rawValue)")
    }

    private func proposalView(_ proposal: InAppEventArtworkProposal) -> some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            InAppEventArtworkProposalPreview(
                path: proposal.push.path, isVideo: proposal.push.isVideo, kind: proposal.kind, texts: overlayTexts(proposal)
            )
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(proposal.isAwaitingAcceptance ? "Suggested by \(proposal.source.title)" : "Accepted · in Review & Push")
                    .font(.callout.weight(.semibold))
                Text(proposal.push.fileName)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(String(localized: "For \(proposal.localesText). Pushing replaces their \(proposal.kind.name)."))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.small) {
                    Button(proposal.isAwaitingAcceptance ? "Dismiss" : "Remove") { onDismiss(proposal) }
                        .accessibilityIdentifier("events.media.dismiss.\(proposal.kind.mcpValue)")
                    if proposal.isAwaitingAcceptance {
                        Button("Accept") { onAccept(proposal) }
                            .rowActionButton()
                            .accessibilityIdentifier("events.media.accept.\(proposal.kind.mcpValue)")
                    }
                }
                .controlSize(.regular)
                .padding(.top, Spacing.xSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .padding(.leading, 28)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.media.proposal.\(proposal.kind.mcpValue)")
    }
}
