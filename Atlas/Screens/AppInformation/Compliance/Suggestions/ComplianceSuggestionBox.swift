//
//  ComplianceSuggestionBox.swift
//  Atlas
//

import SwiftUI

/// An assistant's answer on a compliance card: who suggested it, the
/// answer, why, and Evidence, Dismiss and Accept. Accepting gives the same
/// answer as the card's own buttons.
struct ComplianceSuggestionBox: View {
    let viewModel: AppInformationViewModel
    let suggestion: ComplianceSuggestion

    @State private var showsEvidence = false
    @Environment(\.colorSchemeContrast) private var contrast

    private var identifier: String { "appInformation.compliance.\(suggestion.rule.rawValue).suggestion" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                AssistantProposedTag(client: suggestion.client, text: String(localized: "Suggested"))
                Text(suggestion.answer.title)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("\(identifier).answer")
            }
            if case let .trader(details) = suggestion.answer {
                TraderDetailsGrid(details: details)
            }
            if !suggestion.evidence.why.isEmpty {
                Text(suggestion.evidence.why)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).why")
            }
            HStack(spacing: Spacing.xSmall) {
                if hasEvidence {
                    Button(String(localized: "Evidence…")) { showsEvidence = true }
                        .buttonStyle(.link)
                        .font(.subheadline)
                        .popover(isPresented: $showsEvidence, arrowEdge: .bottom) { popover }
                        .accessibilityIdentifier("\(identifier).evidence")
                }
                Spacer(minLength: 0)
                Button(String(localized: "Dismiss")) { viewModel.dismissComplianceSuggestion(for: suggestion.rule) }
                    .accessibilityIdentifier("\(identifier).dismiss")
                Button(String(localized: "Accept")) { viewModel.acceptComplianceSuggestion(for: suggestion.rule) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("\(identifier).accept")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.machineTranslatedTint, in: shape)
        .overlay(shape.strokeBorder(Palette.machineTranslatedMark.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var hasEvidence: Bool {
        !suggestion.evidence.evidence.isEmpty || suggestion.evidence.couldNotSee != nil
    }

    private var popover: some View {
        AssistantEvidencePopover(
            title: suggestion.rule.title,
            evidence: suggestion.evidence,
            onReject: {
                showsEvidence = false
                viewModel.dismissComplianceSuggestion(for: suggestion.rule)
            },
            onConfirm: {
                showsEvidence = false
                viewModel.acceptComplianceSuggestion(for: suggestion.rule)
            }
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }
}
