//
//  ComplianceSuggestionBox.swift
//  Atlas
//

import SwiftUI

/// An assistant's answer on a compliance card: who suggested it, the
/// answer, why, and Evidence, Dismiss and Accept. Accepting gives the same
/// answer as the card's own buttons, and settles the box (effect 5).
struct ComplianceSuggestionBox: View {
    let viewModel: AppInformationViewModel
    let suggestion: ComplianceSuggestion

    @State private var showsEvidence = false
    @State private var isSettling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var identifier: String { "appInformation.compliance.\(suggestion.rule.rawValue).suggestion" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                AssistantProposedTag(client: suggestion.client, text: String(localized: "Suggested"))
                Text(suggestion.answer.title)
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("\(identifier).answer")
                if let confidence = suggestion.evidence.layers?.confidence { HowSureMeter(confidence: confidence) }
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
                Button(String(localized: "Dismiss")) {
                    AIDecided.dismiss(reduceMotion: reduceMotion) { viewModel.dismissComplianceSuggestion(for: suggestion.rule) }
                }
                .accessibilityIdentifier("\(identifier).dismiss")
                Button(String(localized: "Accept"), action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("\(identifier).accept")
            }
            .controlSize(.regular)
            if let details = suggestion.evidence.layers?.details { SuggestionDetailsDisclosure(details: details) }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        // No arrival: the answer comes with the card's other details.
        .suggestionSurface(isSettling: isSettling, arrivalKey: identifier, arrivedAt: nil)
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

    private func accept() {
        let rule = suggestion.rule
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            viewModel.acceptComplianceSuggestion(for: rule)
        }
    }
}
