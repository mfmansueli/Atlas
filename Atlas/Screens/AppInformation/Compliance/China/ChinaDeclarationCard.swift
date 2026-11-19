//
//  ChinaDeclarationCard.swift
//  Atlas
//

import SwiftUI

/// China mainland's Security Assessment or AI-generated content
/// declaration, asked of every app (No for one not sold there): Yes, No, or
/// stop selling in China mainland. Apple's API neither shows nor takes Yes and No, so they
/// wait here (with the AI filing, or the list of what the Security
/// Assessment needs) until the person enters them in App Store Connect and
/// marks them as declared. Stopping sales is pushed.
struct ChinaDeclarationCard: View {
    @Bindable var viewModel: AppInformationViewModel
    let report: ComplianceReport
    let rule: ComplianceRule

    private var choice: ChinaDeclarationChoice? { viewModel.chinaChoice(for: rule) }

    var body: some View {
        ComplianceCard(rule: rule, state: report.state(of: rule), detail: report.detail(for: rule)) {
            if let suggestion = viewModel.complianceSuggestion(for: rule) {
                ComplianceSuggestionBox(viewModel: viewModel, suggestion: suggestion)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.chinaChoices) { option in
                    RadioRow(
                        title: option.title(for: rule),
                        detail: option.detail(for: rule, appName: viewModel.app.name, isSoldThere: report.chinaDeclarations.isSoldThere),
                        isSelected: choice == option
                    ) {
                        viewModel.chooseChina(option, for: rule)
                    }
                    .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).\(option.rawValue)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(rule.name))
            if choice == .yes {
                Group {
                    if rule == .aiGeneratedContent {
                        AIFilingFields(viewModel: viewModel)
                    } else {
                        SecurityAssessmentChecklist()
                    }
                }
                .padding(.leading, 34)
            }
            footer
        }
    }

    private var footer: some View {
        HStack(spacing: Spacing.xSmall) {
            Text("Apple’s API can’t take or show this one.")
                .font(.caption)
                .foregroundStyle(Palette.label3)
                .frame(maxWidth: .infinity, alignment: .leading)
            ExternalLinkButton(title: String(localized: "Open App Store Connect"), url: viewModel.appStoreConnectComplianceURL)
            Button(String(localized: "Mark as Declared")) { viewModel.setDeclared(true, for: rule) }
                .buttonStyle(.borderedProminent)
                .disabled(report.state(of: rule) != .toEnter)
                .help(Text("Once you’ve entered your answer in App Store Connect"))
                .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).markDeclared")
        }
        .controlSize(.small)
    }
}
