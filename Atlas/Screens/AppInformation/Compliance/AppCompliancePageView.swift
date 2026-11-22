//
//  AppCompliancePageView.swift
//  Atlas
//

import SwiftUI

/// App Compliance: the regulations that apply in some countries or to some
/// kinds of apps. The Digital Services Act, the ICP Filing Number and China
/// mainland's Security Assessment and AI content declarations take the
/// person's answer; the Vietnam game license and regulated medical devices
/// are checked from the app's category, age rating and countries, and only
/// ask when Apple does.
///
/// Nothing on this page goes through the suggestion bar or Accept All:
/// compliance answers are the person's to give. An assistant may suggest
/// some (Ask), and each waits on its card until the person accepts it.
struct AppCompliancePageView: View {
    @Bindable var viewModel: AppInformationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            AppInformationPageHeader(
                title: AppInformationPage.appCompliance.title,
                subtitle: AppInformationPage.appCompliance.summary(appName: viewModel.app.name, version: nil)
            )
            AppInformationPageBar(viewModel: viewModel, page: .appCompliance)
            if let report = viewModel.complianceReport {
                loaded(report)
            } else if case let .failed(message) = viewModel.compliance {
                AccessibilityLoadErrorView(
                    message: message,
                    requestLine: viewModel.complianceErrorLine,
                    identifier: "appInformation.compliance"
                ) {
                    Task { await viewModel.loadCompliance() }
                }
            } else {
                AppInformationPageSkeleton()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appCompliance")
    }

    @ViewBuilder
    private func loaded(_ report: ComplianceReport) -> some View {
        banner(report)
        if let assistant = viewModel.complianceSuggestionBanner {
            AssistantAnswersBanner(client: assistant.client, text: assistant.text)
                .accessibilityIdentifier("appInformation.compliance.suggestions")
        }
        if let line = viewModel.complianceErrorLine {
            InlineMessage.warning(String(localized: "Couldn’t check again where \(viewModel.app.name) is sold. This is what was read before. \(line)"))
                .accessibilityIdentifier("appInformation.compliance.stale")
        }
        ForEach(ComplianceRule.allCases) { rule in
            if report.state(of: rule) == .passes {
                CompliancePassRow(viewModel: viewModel, report: report, rule: rule)
            } else {
                card(for: rule, report)
            }
        }
        Text("Checked again whenever \(viewModel.app.name)’s category, age rating or countries change.")
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
    }

    @ViewBuilder
    private func card(for rule: ComplianceRule, _ report: ComplianceReport) -> some View {
        switch rule {
        case .traderStatus: TraderStatusCard(viewModel: viewModel, report: report)
        case .icpFilingNumber: ICPFilingCard(viewModel: viewModel, report: report)
        case .securityAssessment, .aiGeneratedContent: ChinaDeclarationCard(viewModel: viewModel, report: report, rule: rule)
        case .vietnamGameLicense, .medicalDevice: ComplianceDeclarationCard(viewModel: viewModel, report: report, rule: rule)
        }
    }

    private func banner(_ report: ComplianceReport) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("\(report.headline). Compliance answers are yours: Atlas prepares them and checks them, and never accepts them for you, not even with Accept All.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("appInformation.compliance.headline")
            if !report.isUpToDate {
                ComplianceAskButton(app: viewModel.app)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + 2)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.banner")
    }
}
