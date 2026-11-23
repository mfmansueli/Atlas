//
//  CompliancePassRow.swift
//  Atlas
//

import SwiftUI

/// A regulation with nothing left to do: a check, "Vietnam Game License ·
/// not needed", why, and what checked it. One the person marked as
/// declared offers Change; the Digital Services Act links to App Store
/// Connect, where the declaration can be read.
struct CompliancePassRow: View {
    let viewModel: AppInformationViewModel
    let report: ComplianceReport
    let rule: ComplianceRule

    var body: some View {
        HStack(spacing: 10) {
            StatusMark(isOK: true, size: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(report.passTitle(for: rule))
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).title")
                Text(report.detail(for: rule))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).detail")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: shape)
        .overlay { shape.strokeBorder(Palette.separator, lineWidth: 0.5) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card - 2, style: .continuous)
    }

    @ViewBuilder
    private var trailing: some View {
        if report.isMarkedDeclared(rule) {
            Button(String(localized: "Change")) { viewModel.setDeclared(false, for: rule) }
                .buttonStyle(.link)
                .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).change")
        } else if rule == .traderStatus, report.trader == .declared {
            ExternalLinkButton(title: String(localized: "App Store Connect"), url: viewModel.appStoreConnectComplianceURL, isLink: true)
        } else if rule == .medicalDevice {
            Button(String(localized: "Age Rating")) { viewModel.page = .ageRating }
                .buttonStyle(.link)
                .accessibilityIdentifier("appInformation.compliance.\(rule.rawValue).ageRating")
        } else {
            SuggestionSourceTag(source: .builtIn)
        }
    }
}
