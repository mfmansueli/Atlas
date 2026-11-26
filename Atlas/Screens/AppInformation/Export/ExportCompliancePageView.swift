//
//  ExportCompliancePageView.swift
//  Atlas
//

import SwiftUI

/// Export Compliance: the encryption questions, an assistant's answers
/// with their evidence, and the Info.plist key that skips the question.
struct ExportCompliancePageView: View {
    @Bindable var viewModel: AppInformationViewModel

    var body: some View {
        if let answers = viewModel.exportAnswers {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Each question says only Apple sees it (board 88).
                AppInformationPageTools(whereShown: nil) {
                    Pill(text: answers.status)
                        .fixedSize()
                        .accessibilityIdentifier("appInformation.export.status")
                }
                if let evidence = viewModel.notes.exportEvidence {
                    assistantBanner(evidence)
                }
                if let notice = viewModel.exportNotice {
                    InlineMessage.warning(notice)
                        .accessibilityIdentifier("appInformation.export.notice")
                }
                AppInformationFormSection(title: String(localized: "Encryption")) {
                    ForEach(Array(answers.visibleQuestions.enumerated()), id: \.element) { index, question in
                        if index > 0 { Divider() }
                        AppInformationFormRow(label: question.title, detail: question.subtitle, whereShown: AppInformationFieldPlacement.onlyApple) {
                            YesNoPicker(title: question.title, value: answers[question]) {
                                viewModel.setExportAnswer($0, for: question)
                            }
                            .accessibilityIdentifier("appInformation.export.\(question.rawValue)")
                        }
                    }
                }
                if viewModel.exportAnswersAreFromBuild, let build = viewModel.content?.export.buildNumber {
                    fromBuildNote(build: build)
                }
                if let declaration = viewModel.queuedDeclaration {
                    Text("\(declaration.title): \(declaration.newValue), waiting in Review & Push.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("appInformation.export.declaration")
                }
                if let build = viewModel.content?.export.buildNumber, let usesNonExempt = answers.usesNonExemptEncryption {
                    (usesNonExempt
                        ? Text("Build \(build) is told it uses non-exempt encryption, so it needs an encryption declaration.")
                        : Text("Build \(build) is told it uses no non-exempt encryption, so it needs no documents."))
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                InfoPlistKeyCard(viewModel: viewModel)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appInformation.exportCompliance")
        }
    }

    /// The answers come only from the build's flag, which can't tell
    /// exempt encryption from none at all: say so, instead of claiming the
    /// app uses no encryption.
    private func fromBuildNote(build: String) -> some View {
        Label {
            Text("""
            From build \(build)’s answer, which can’t tell exempt encryption (such as HTTPS) from none. Change the \
            answers if they’re wrong.
            """)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.subheadline)
        .foregroundStyle(Palette.label2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appInformation.export.fromBuild")
    }

    private func assistantBanner(_ evidence: AssistantEvidence) -> some View {
        AssistantAnswersBanner(client: evidence.client, text: String(localized: "answered from the app’s use of cryptography")) {
            Button(String(localized: "Evidence")) { viewModel.showsExportEvidence = true }
                .buttonStyle(.link)
                .accessibilityIdentifier("appInformation.export.evidence")
                .popover(isPresented: $viewModel.showsExportEvidence, arrowEdge: .bottom) {
                    AssistantEvidencePopover(
                        title: String(localized: "Export compliance"),
                        evidence: evidence,
                        onReject: { viewModel.rejectExportEvidence() },
                        onConfirm: { viewModel.confirmExportEvidence() }
                    )
                }
        }
    }
}
