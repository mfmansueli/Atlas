//
//  ComplianceDeclarationCard.swift
//  Atlas
//

import SwiftUI

/// The Vietnam game license or the regulated medical device declaration,
/// when Apple asks for it. Apple's API neither takes nor shows it, so the
/// card opens App Store Connect and lets the person say once it's done
/// there. An assistant may suggest the medical device answer.
struct ComplianceDeclarationCard: View {
    let viewModel: AppInformationViewModel
    let report: ComplianceReport
    let rule: ComplianceRule

    var body: some View {
        ComplianceCard(rule: rule, state: report.state(of: rule), detail: report.detail(for: rule)) {
            if let suggestion = viewModel.complianceSuggestion(for: rule) {
                ComplianceSuggestionBox(viewModel: viewModel, suggestion: suggestion)
            }
            HStack(spacing: Spacing.xSmall) {
                Text("Apple’s API can’t take or show this one.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hasAnswer {
                    Button(String(localized: "Change")) { viewModel.clearMedicalDeviceAnswer() }
                        .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).changeAnswer")
                }
                ExternalLinkButton(title: String(localized: "Open App Store Connect"), url: viewModel.appStoreConnectComplianceURL)
                if canMarkDeclared {
                    Button(String(localized: "Mark as Declared")) { viewModel.setDeclared(true, for: rule) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).markDeclared")
                }
            }
            .controlSize(.small)
        }
    }

    /// An accepted answer to the medical device question, which the
    /// detail line repeats.
    private var hasAnswer: Bool {
        rule == .medicalDevice && report.answers.regulatedMedicalDevice != nil
    }

    /// While Apple itself says something is missing, saying it's done
    /// wouldn't make it so.
    private var canMarkDeclared: Bool {
        !(rule == .vietnamGameLicense && report.gameLicense == .flaggedByApple)
    }
}
