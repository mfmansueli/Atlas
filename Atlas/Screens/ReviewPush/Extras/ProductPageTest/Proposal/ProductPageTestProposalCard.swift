//
//  ProductPageTestProposalCard.swift
//  Atlas
//

import SwiftUI

/// A Product Page Optimization test an assistant proposed, in Review &
/// Push's header and search section: its name, placement, traffic and
/// languages, the treatment, and why, with Review Test… (the sheet,
/// prefilled, where the person creates it) and Dismiss. Nothing reaches
/// App Store Connect from here.
struct ProductPageTestProposalCard: View {
    let proposal: ProductPageTestProposal
    let plan: ExtrasReviewPlan
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.small) {
                Image(systemName: "testtube.2").foregroundStyle(Palette.label2).accessibilityHidden(true)
                Text("Proposed test · \(proposal.placement.title)").font(.callout.weight(.semibold))
                Spacer(minLength: Spacing.small)
                Button("Dismiss", action: onDismiss)
                    .controlSize(.regular)
                    .help(String(localized: "Leaves it out. Nothing changes in App Store Connect."))
                    .accessibilityIdentifier("review.extras.testProposal.dismiss")
                Button("Review Test…", action: onOpen)
                    .controlSize(.regular)
                    .help(String(localized: "Opens it in Test with Product Page Optimization, filled in. You create the test there."))
                    .accessibilityIdentifier("review.extras.testProposal.open")
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(Palette.fill1)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(spacing: Spacing.xSmall) {
                    Text(proposal.name).font(.callout.weight(.semibold))
                        .accessibilityIdentifier("review.extras.testProposal.name")
                    if let confidence = proposal.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
                Text(proposal.summary + " · " + treatmentLine)
                    .font(.subheadline).foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(proposal.client): \(proposal.reason)")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("review.extras.testProposal.reason")
                ForEach(proposal.evidence, id: \.self) { line in
                    Label(line, systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline).foregroundStyle(Palette.label2)
                        .labelStyle(.titleAndIcon)
                }
                if let details = proposal.layers?.details { SuggestionDetailsDisclosure(details: details) }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.raised)
        .clipShape(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
                .strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.extras.testProposal.\(proposal.id)")
    }

    /// "the run's variant: A calm morning page…", "waiting for the
    /// variant", "images from the app's library".
    private var treatmentLine: String {
        switch proposal.treatment {
        case .library:
            return String(localized: "images from the app’s library")
        case .variant:
            let role: ArtworkTextRole = proposal.placement == .header ? .header : .search
            guard let variant = plan.variant, variant.role == role, plan.kind(for: proposal.placement) == variant.kind else {
                return String(localized: "waiting for the variant")
            }
            return String(localized: "the run’s variant: \(variant.change)")
        }
    }
}
