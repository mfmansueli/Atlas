//
//  AppInformationPageColumn.swift
//  Atlas
//

import SwiftUI

/// General · App Compliance · Age Rating · Accessibility · App Privacy · App
/// Review · Export Compliance, under the section's name, each with its status and how many
/// suggestions wait on it.
struct AppInformationPageColumn: View {
    @Bindable var viewModel: AppInformationViewModel

    var body: some View {
        List(selection: selection) {
            ForEach(AppInformationPage.allCases) { page in
                AppInformationPageRow(
                    page: page,
                    status: viewModel.pageColumnStatus(for: page),
                    suggestionCount: viewModel.suggestionCount(on: page),
                    comingCount: viewModel.comingCount(on: page),
                    isUpToDate: viewModel.isPageUpToDate(page),
                    needsPerson: page == .appCompliance && viewModel.complianceReport?.isUpToDate == false,
                    hasPendingChanges: viewModel.hasPendingChanges(on: page)
                )
                .tag(page)
            }
        }
        // Rows hold row-sized (24 pt) controls.
        .controlSize(.regular)
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        // README — redesign, November 22: the title shows once, in the toolbar.
        .contentMargins(.top, Spacing.small, for: .scrollContent)
        .safeAreaInset(edge: .bottom) {
            Text("Details Apple asks for with each version. Most never show on the page.")
                .font(.footnote)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.medium)
        }
        .frame(width: 200)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("App Information pages"))
        .accessibilityIdentifier("appInformation.pageColumn")
    }

    private var selection: Binding<AppInformationPage?> {
        Binding(get: { viewModel.page }, set: { page in if let page { viewModel.page = page } })
    }
}
