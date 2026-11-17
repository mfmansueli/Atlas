//
//  ComplianceDeclarationCard.swift
//  Atlas
//

import SwiftUI

/// The Vietnam game license or the regulated medical device declaration,
/// when Apple asks for it. Apple's API neither takes nor shows it, so the
/// card opens App Store Connect and lets the person say once it's done
/// there.
struct ComplianceDeclarationCard: View {
    let viewModel: AppInformationViewModel
    let report: ComplianceReport
    let rule: ComplianceRule

    var body: some View {
        ComplianceCard(rule: rule, state: report.state(of: rule), detail: report.detail(for: rule)) {
            HStack(spacing: Spacing.xSmall) {
                Text("Apple’s API can’t take or show this one.")
                    .font(.caption)
                    .foregroundStyle(Palette.label3)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    /// While Apple itself says something is missing, saying it's done
    /// wouldn't make it so.
    private var canMarkDeclared: Bool {
        !(rule == .vietnamGameLicense && report.gameLicense == .flaggedByApple)
    }
}
