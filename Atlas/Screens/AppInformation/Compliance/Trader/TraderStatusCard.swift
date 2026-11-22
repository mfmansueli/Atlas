//
//  TraderStatusCard.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The Digital Services Act while it isn't settled. With no status at
/// Apple: the question, with the trader details prepared and editable
/// before the person decides, then their answer with what's left to do in
/// App Store Connect, since Apple's API doesn't take it. With details
/// Apple couldn't verify: where to correct them.
struct TraderStatusCard: View {
    @Bindable var viewModel: AppInformationViewModel
    let report: ComplianceReport

    var body: some View {
        ComplianceCard(rule: .traderStatus, state: report.state(of: .traderStatus), detail: report.detail(for: .traderStatus)) {
            if let suggestion = viewModel.complianceSuggestion(for: .traderStatus) {
                ComplianceSuggestionBox(viewModel: viewModel, suggestion: suggestion)
            }
            switch (report.trader, report.answers.trader) {
            case (.notProvided, nil): question
            case let (.notProvided, decision?): answered(decision)
            default: connectLink
            }
        }
    }

    // MARK: - The question

    /// Atlas's own "Suggested", unless an assistant suggested an answer.
    private var showsBuiltInSuggestion: Bool {
        report.suggestsTrader && viewModel.complianceSuggestion(for: .traderStatus) == nil
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                if showsBuiltInSuggestion {
                    Pill(text: String(localized: "Suggested"), style: .machineTranslated)
                    SuggestionSourceTag(source: .builtIn)
                }
                Text(report.traderReason)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("appInformation.compliance.trader.reason")
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
                GridRow {
                    Text("NOW")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.label2)
                        .frame(width: 74, alignment: .leading)
                    Text("Not declared")
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GridRow {
                    Text(showsBuiltInSuggestion ? "SUGGESTED" : "AS A TRADER")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(showsBuiltInSuggestion ? Palette.machineTranslated : Palette.label2)
                        .frame(width: 74, alignment: .leading)
                    Text("Trader, with these details")
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                TraderDetailsGrid(details: viewModel.traderDetails, isEditing: viewModel.isEditingTrader) { text, field in
                    viewModel.setTraderDetail(text, for: field)
                }
                Text("Prepared from your team’s name and App Review’s contact. Apple’s API doesn’t share your address: add it yourself.")
                    .font(.caption2)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 84)
            HStack(spacing: Spacing.xSmall) {
                Spacer(minLength: 0)
                Button(String(localized: "Stay a Non-Trader")) { viewModel.decideTrader(.nonTrader) }
                    .accessibilityIdentifier("appInformation.compliance.trader.decline")
                if viewModel.isEditingTrader {
                    Button(String(localized: "Done")) { viewModel.isEditingTrader = false }
                        .accessibilityIdentifier("appInformation.compliance.trader.done")
                } else {
                    Button(String(localized: "Edit Details…")) { viewModel.isEditingTrader = true }
                        .accessibilityIdentifier("appInformation.compliance.trader.edit")
                }
                Button(String(localized: "I’m a Trader")) { viewModel.decideTrader(.trader) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("appInformation.compliance.trader.accept")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(showsBuiltInSuggestion ? Palette.machineTranslatedTint : Palette.fill1, in: boxShape)
        .overlay {
            boxShape.strokeBorder(showsBuiltInSuggestion ? Palette.machineTranslatedMark.opacity(0.35) : Palette.separator, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.trader.question")
    }

    private var boxShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    // MARK: - The answer

    private func answered(_ decision: TraderDecision) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(answerText(decision))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("appInformation.compliance.trader.answer")
            if decision == .trader {
                TraderDetailsGrid(details: viewModel.traderDetails)
            }
            HStack(spacing: Spacing.xSmall) {
                Spacer(minLength: 0)
                Button(String(localized: "Change")) { viewModel.reopenTrader() }
                    .accessibilityIdentifier("appInformation.compliance.trader.change")
                if decision == .trader {
                    Button(String(localized: "Copy Details")) { copyDetails() }
                        .accessibilityIdentifier("appInformation.compliance.trader.copy")
                }
                ExternalLinkButton(title: String(localized: "Open App Store Connect"), url: viewModel.appStoreConnectComplianceURL)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentTint, in: boxShape)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.trader.answered")
    }

    private func answerText(_ decision: TraderDecision) -> String {
        let app = viewModel.app.name
        switch decision {
        case .trader:
            return String(localized: "Trader, with these details. Apple’s API doesn’t take them: enter them in App Store Connect.")
                + " " + String(localized: "Apple verifies the phone and the email there with a code.")
        case .nonTrader:
            return String(localized: "Non-trader. Apple’s API doesn’t take the declaration: make it in App Store Connect.")
                + " " + String(localized: "\(app)’s page in the EU then shows no trader details.")
        }
    }

    private func copyDetails() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.traderDetails.pasteboardText, forType: .string)
        viewModel.toast = String(localized: "Copied the trader details.")
    }

    // MARK: - Apple couldn't verify

    private var connectLink: some View {
        HStack {
            Spacer(minLength: 0)
            ExternalLinkButton(title: String(localized: "Open App Store Connect"), url: viewModel.appStoreConnectComplianceURL)
                .controlSize(.small)
        }
    }
}
