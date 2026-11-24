//
//  NominationProposalCard.swift
//  Atlas
//

import SwiftUI

/// An assistant's new nomination at the top of Drafts, in purple: who
/// suggested it, how sure, what it is and why, with Review… and Dismiss.
/// It isn't a draft until the person accepts it.
struct NominationProposalCard: View {
    let proposal: NominationProposal
    let onReview: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Suggested", comment: "kind:pill"), style: .machineTranslated)
                SuggestionSourceTag(source: .assistant(client: proposal.client))
                Spacer(minLength: 0)
                if let confidence = proposal.evidence.layers?.confidence { HowSureMeter(confidence: confidence) }
            }
            Text(proposal.content.trimmedName)
                .font(.headline)
                .lineLimit(2)
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text([proposal.content.type?.title, NominationDayText.dates(proposal.content)].compactMap(\.self).joined(separator: " · "))
                Text(NominationDevice.list(proposal.content.devices))
            }
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            SuggestedText(proposal.evidence.why, arrivalKey: arrivalKey, arrivedAt: proposal.receivedAt)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Spacing.small) {
                Spacer(minLength: 0)
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss) }
                    .accessibilityIdentifier("nominations.proposal.dismiss")
                Button("Review…", action: onReview)
                    .rowActionButton()
                    .accessibilityIdentifier("nominations.proposal.review")
            }
            .buttonBorderShape(.capsule)
        }
        .padding(Spacing.medium)
        .suggestionSurface(isSettling: false, arrivalKey: arrivalKey, arrivedAt: proposal.receivedAt, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggested by \(proposal.client): \(proposal.content.trimmedName)"))
        .accessibilityIdentifier("nominations.proposal")
    }

    private var arrivalKey: String { "nomination|\(proposal.id)|\(proposal.receivedAt.timeIntervalSinceReferenceDate)" }
}
