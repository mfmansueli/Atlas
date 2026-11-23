//
//  PrivacyDataTypeReviewLine.swift
//  Atlas
//

import SwiftUI

/// A row's last line: the assistant's evidence (Evidence · N opens each
/// piece, the references follow it), an open question about the type, and
/// Reject and Accept while unreviewed. Nothing when there's none of these.
struct PrivacyDataTypeReviewLine: View {
    @Bindable var viewModel: AppPrivacyViewModel
    let type: PrivacyDataType
    let entry: PrivacyTypeEntry

    var body: some View {
        let question = viewModel.worksheet.openQuestion(about: type)
        if evidence != nil || question != nil || entry.status == .unreviewed {
            line(question: question)
        }
    }

    /// The suggestion's evidence, unless the person's own answer won.
    private var evidence: [PrivacyEvidence]? {
        guard let suggestion = entry.suggestion, entry.status != .yours || entry.conflict == nil, !suggestion.evidence.isEmpty
        else { return nil }
        return suggestion.evidence
    }

    private func line(question: PrivacyOpenQuestion?) -> some View {
        HStack(spacing: Spacing.small) {
            if let evidence {
                Button(String(localized: "Evidence · \(evidence.count)")) {
                    viewModel.evidenceType = type
                }
                .controlSize(.regular)
                .popover(isPresented: Binding(
                    get: { viewModel.evidenceType == type },
                    set: { if !$0, viewModel.evidenceType == type { viewModel.evidenceType = nil } }
                ), arrowEdge: .bottom) {
                    PrivacyEvidencePopover(viewModel: viewModel, type: type, entry: entry)
                }
                .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue).evidence")
                Text(evidence.map(\.reference).joined(separator: "  ·  "))
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(evidence.map(\.reference).joined(separator: "\n"))
                    .accessibilityHidden(true)
            }
            if let question {
                Label(String(localized: "Open question"), systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Palette.warn)
                    .help(question.question)
            }
            Spacer(minLength: 0)
            if entry.status == .unreviewed {
                Button(String(localized: "Reject")) { viewModel.reject(type) }
                    .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue).reject")
                Button(String(localized: "Accept")) { viewModel.accept(type) }
                    .rowActionButton()
                    .disabled(entry.answer.isMissingPurpose)
                    .accessibilityIdentifier("appInformation.appPrivacy.type.\(type.rawValue).accept")
            }
        }
        .controlSize(.regular)
    }
}
