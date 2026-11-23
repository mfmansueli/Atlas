//
//  ProductPageTestProposalNote.swift
//  Atlas
//

import SwiftUI

/// The top of “Test with Product Page Optimization…” opened from an
/// assistant's proposal: who proposed it and why, its name, traffic and
/// languages, and whether Create Test also sends it to App Review (the
/// proposal's choice to start with; the person decides).
struct ProductPageTestProposalNote: View {
    let proposal: ProductPageTestProposal
    @Binding var startsTest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Suggested by \(proposal.client)").font(.callout.weight(.semibold))
            Text(proposal.reason)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ppo.proposal.reason")
            ForEach(proposal.evidence, id: \.self) { line in
                Label(line, systemImage: "doc.text.magnifyingglass")
                    .font(.subheadline).foregroundStyle(Palette.label2)
                    .labelStyle(.titleAndIcon)
            }
            Text("“\(proposal.name)” · \(proposal.trafficProportion)% of visitors see the treatment")
                .font(.subheadline).foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ppo.proposal.summary")
            Toggle("Send it to App Review once it’s made", isOn: $startsTest)
                .toggleStyle(.checkbox)
                .font(.subheadline)
                .help(String(localized: "Off, it stays a draft you start in App Store Connect."))
                .accessibilityIdentifier("ppo.startsTest")
        }
        .padding(Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ppo.proposal")
    }
}
