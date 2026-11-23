//
//  PrivacyWorksheetFilterBar.swift
//  Atlas
//

import SwiftUI

/// Under "What … collects": the filters with their counts and Show All 35
/// Data Types.
struct PrivacyWorksheetFilterBar: View {
    @Bindable var viewModel: AppPrivacyViewModel

    var body: some View {
        // Wraps under a narrow window instead of pushing the page wider.
        FlowLayout(spacing: Spacing.small) {
            Picker(String(localized: "Show"), selection: $viewModel.filter) {
                ForEach(PrivacyWorksheetFilter.allCases) { filter in
                    Text(viewModel.title(of: filter)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.regular)
            .fixedSize()
            .accessibilityIdentifier("appInformation.appPrivacy.filter")
            Button(viewModel.showsAllTypes
                ? String(localized: "Hide Untouched Types")
                : String(localized: "Show All \(PrivacyDataType.allCases.count) Data Types"))
            {
                viewModel.showsAllTypes.toggle()
                viewModel.filter = .all
            }
            .controlSize(.regular)
            .accessibilityIdentifier("appInformation.appPrivacy.showAll")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
