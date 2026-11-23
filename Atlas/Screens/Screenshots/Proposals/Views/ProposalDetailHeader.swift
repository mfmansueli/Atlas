//
//  ProposalDetailHeader.swift
//  Atlas
//

import SwiftUI

/// The selected proposal's title, who sent it and on which version, the
/// assistant's why, and once decided, what happened.
struct ProposalDetailHeader: View {
    let proposal: ScreenshotProposal
    let meta: String
    let outcome: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(proposal.title)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("proposals.detail.title")
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.xSmall) {
                    Text("Why · from \(proposal.client)")
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.label2)
                    if let confidence = proposal.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
                Text(proposal.reason)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.medium)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.field + 2, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field + 2, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 0.5)
            }
            .accessibilityElement(children: .combine)
            if let details = proposal.layers?.details { SuggestionDetailsDisclosure(details: details) }
            if let outcome {
                Label(outcome, systemImage: proposal.status == .rejected ? "xmark.circle" : "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("proposals.detail.outcome")
            }
        }
    }
}
