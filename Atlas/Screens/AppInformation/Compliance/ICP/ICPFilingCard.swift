//
//  ICPFilingCard.swift
//  Atlas
//

import AppKit
import SwiftUI

/// China mainland's ICP Filing Number while Apple asks for one: add the
/// number, checked for its format here and entered in App Store Connect
/// (Apple's API doesn't take it), or stop selling in China mainland, which
/// goes through Review & Push.
struct ICPFilingCard: View {
    @Bindable var viewModel: AppInformationViewModel
    let report: ComplianceReport

    var body: some View {
        ComplianceCard(rule: .icpFilingNumber, state: report.state(of: .icpFilingNumber), detail: report.detail(for: .icpFilingNumber)) {
            if let suggestion = viewModel.complianceSuggestion(for: .icpFilingNumber) {
                ComplianceSuggestionBox(viewModel: viewModel, suggestion: suggestion)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ICPChoice.allCases) { choice in
                    RadioRow(
                        title: choice.title,
                        detail: choice.detail(appName: viewModel.app.name),
                        isSelected: viewModel.icpChoice == choice
                    ) {
                        viewModel.chooseICP(choice)
                    }
                    .accessibilityIdentifier("appInformation.compliance.icp.\(choice.rawValue)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("ICP Filing Number"))
            switch viewModel.icpChoice {
            case .addNumber: number
            case .stopSelling: stopSelling
            case nil: EmptyView()
            }
        }
    }

    private var number: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            TextField(ICPFilingNumber.example, text: Binding(get: { report.answers.icpNumber }, set: { viewModel.setICPNumber($0) }))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .accessibilityLabel(Text("ICP Filing Number"))
                .accessibilityIdentifier("appInformation.compliance.icp.number")
            if report.answers.hasMalformedICPNumber {
                InlineMessage.warning(String(localized: "That doesn’t look like an ICP Filing Number. It reads like \(ICPFilingNumber.example)."))
                    .font(.caption)
                    .accessibilityIdentifier("appInformation.compliance.icp.malformed")
            }
            if report.answers.hasValidICPNumber {
                Text("Format checked. Apple’s API doesn’t take the number: paste it in App Store Connect, under App Compliance.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("appInformation.compliance.icp.checked")
                HStack(spacing: Spacing.xSmall) {
                    Spacer(minLength: 0)
                    Button(String(localized: "Copy Number")) { copyNumber() }
                        .accessibilityIdentifier("appInformation.compliance.icp.copy")
                    ExternalLinkButton(title: String(localized: "Open App Store Connect"), url: viewModel.appStoreConnectComplianceURL)
                }
                .controlSize(.small)
            }
        }
        .padding(.leading, 34)
    }

    private var stopSelling: some View {
        Text("China mainland comes off \(viewModel.app.name)’s availability when you push.")
            .font(.caption)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 34)
            .accessibilityIdentifier("appInformation.compliance.icp.stops")
    }

    private func copyNumber() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ICPFilingNumber.normalized(report.answers.icpNumber), forType: .string)
        viewModel.toast = String(localized: "Copied the ICP Filing Number.")
    }
}
