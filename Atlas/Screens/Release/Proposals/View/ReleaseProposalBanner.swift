//
//  ReleaseProposalBanner.swift
//  Atlas
//

import SwiftUI

/// On the version card, what an assistant proposed over MCP: who, what
/// ("Release 1.4 now"), Submit's choices, why, the evidence, and Dismiss
/// or Confirm. Confirm runs the card's own action (which asks first where
/// it asks), or opens the Submit sheet with the choices; nothing is sent
/// before. A proposal the version no longer allows says why, with Dismiss
/// only.
struct ReleaseProposalBanner: View {
    let viewModel: ReleaseViewModel
    let proposal: ReleaseProposal
    /// Opens the Submit sheet.
    let onSubmit: () -> Void

    @State private var showsEvidence = false

    private let identifier = "overview.version.proposal"

    var body: some View {
        let problem = viewModel.proposalProblem(proposal)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                AssistantProposedTag(client: proposal.client)
                Text(proposal.title)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("\(identifier).title")
            }
            let lines = viewModel.proposalLines(proposal)
            if !lines.isEmpty {
                Text(lines.joined(separator: " · "))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).choices")
            }
            if !proposal.evidence.why.isEmpty {
                Text(proposal.evidence.why)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).reason")
            }
            if let problem {
                InlineMessage.warning(String(localized: "No longer possible. \(problem)"))
                    .font(.subheadline)
                    .accessibilityIdentifier("\(identifier).outdated")
            }
            HStack(spacing: Spacing.xSmall) {
                if !proposal.evidence.evidence.isEmpty {
                    Button("Evidence…") { showsEvidence = true }
                        .buttonStyle(.link)
                        .font(.subheadline)
                        .popover(isPresented: $showsEvidence, arrowEdge: .bottom) { popover(canConfirm: problem == nil) }
                        .accessibilityIdentifier("\(identifier).evidence")
                }
                Text(problem == nil ? "Nothing is sent until you confirm." : "")
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss") { viewModel.dismissProposal(proposal) }
                    .accessibilityIdentifier("\(identifier).dismiss")
                if problem == nil {
                    Button(proposal.action.confirmTitle(version: proposal.versionString), action: confirm)
                        .rowActionButton()
                        .accessibilityIdentifier("\(identifier).confirm")
                }
            }
            .controlSize(.regular)
            .disabled(viewModel.busyAction != nil)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .suggestionSurface(isSettling: false, arrivalKey: proposal.id, arrivedAt: proposal.receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggested by \(proposal.client): \(proposal.title)"))
        .accessibilityIdentifier(identifier)
    }

    private func popover(canConfirm: Bool) -> some View {
        AssistantEvidencePopover(
            title: proposal.title,
            evidence: proposal.evidence,
            onReject: {
                showsEvidence = false
                viewModel.dismissProposal(proposal)
            },
            onConfirm: {
                showsEvidence = false
                if canConfirm { confirm() }
            }
        )
    }

    private func confirm() {
        if viewModel.confirmProposal(proposal) { onSubmit() }
    }
}
