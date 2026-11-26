//
//  AppPrivacyHeader.swift
//  Atlas
//

import SwiftUI

/// The top of App Privacy, under the section's top and page strip (board
/// 88): the line that says this is a worksheet Atlas can't push, then the
/// three tabs (the worksheet's with what waits in it), the status and
/// Export….
struct AppPrivacyHeader: View {
    @Bindable var viewModel: AppPrivacyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            notASync
            HStack(alignment: .center, spacing: Spacing.small) {
                BadgedSegments(label: String(localized: "App Privacy view"), options: tabs, selection: $viewModel.tab)
                    .accessibilityIdentifier("appInformation.appPrivacy.tabs")
                Spacer(minLength: Spacing.small)
                PrivacyPageStatusPill(status: PrivacyPageStatus(worksheet: viewModel.worksheet))
                    .layoutPriority(-1)
                Button(String(localized: "Export…")) {
                    viewModel.isExportSheetPresented = true
                }
                .controlSize(.regular)
                .disabled(viewModel.worksheet.reviewedAnswers.collects == nil)
                .accessibilityIdentifier("appInformation.appPrivacy.export")
            }
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.medium)
        .padding(.bottom, Spacing.medium)
    }

    /// Worksheet carries the count of what waits in it.
    private var tabs: [(value: AppPrivacyTab, title: String, count: Int)] {
        AppPrivacyTab.allCases.map { tab in
            (tab, tab.title, tab == .worksheet ? PrivacyPageStatus.worksheetCount(viewModel.worksheet) : 0)
        }
    }

    private var notASync: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "shield")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("""
            **A worksheet, not a push.** Apple has no App Privacy API. Build answers here, then copy them into App Store \
            Connect with the checklist. Privacy URLs go through Review & Push.
            """)
            .font(.callout)
            .foregroundStyle(Palette.label2)
            .layoutPriority(1)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("appInformation.appPrivacy.notASync")
    }
}
