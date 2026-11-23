//
//  AppPrivacyHeader.swift
//  Atlas
//

import SwiftUI

/// The top of App Privacy, as the canvas lays it out: the page's title,
/// the line that says this is a worksheet Atlas can't push, then the
/// three tabs (the worksheet's with what waits in it), the status and
/// Export….
struct AppPrivacyHeader: View {
    @Bindable var viewModel: AppPrivacyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AppInformationPageHeader(
                title: AppInformationPage.appPrivacy.title,
                subtitle: AppInformationPage.appPrivacy.summary(appName: viewModel.appShortName, version: nil)
            )
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
        .padding(.top, Spacing.large)
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
            Image(systemName: "lock")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("""
            **A worksheet, not a sync.** App Store Connect has no API for App Privacy, so Atlas can’t read or change the answers \
            there. Build them here, then copy them in with the checklist. The privacy URLs do sync, through Review & Push.
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
