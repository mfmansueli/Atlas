//
//  PrivacyChecklistTab.swift
//  Atlas
//

import SwiftUI

/// "Fill in App Store Connect": the steps to enter the reviewed answers in
/// the order App Store Connect asks, each with Copy and a tick, then Mark
/// as Published. While the worksheet isn't done, an amber line says what's
/// left above the steps, and Mark as Published waits.
struct PrivacyChecklistTab: View {
    let viewModel: AppPrivacyViewModel

    var body: some View {
        let worksheet = viewModel.worksheet
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                PrivacyChecklistIntro(viewModel: viewModel)
                // What's left in the worksheet doesn't close the steps: the
                // person can start, and Mark as Published waits for it.
                if let reason = worksheet.blockedReason, worksheet.publication == nil {
                    blocked(reason)
                }
                if viewModel.showsSteps {
                    PrivacyChecklistSteps(viewModel: viewModel)
                    PrivacyChecklistFooter(viewModel: viewModel)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .leavesChatRoom()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.checklist")
    }

    private func blocked(_ reason: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Text(reason)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Back to Worksheet")) { viewModel.tab = .worksheet }
                .controlSize(.regular)
                .accessibilityIdentifier("appInformation.appPrivacy.checklist.back")
        }
        .padding(Spacing.medium)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.checklist.blocked")
    }
}
