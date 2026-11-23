//
//  PrivacyCategoryBox.swift
//  Atlas
//

import SwiftUI

/// One of the questionnaire's categories, e.g. Identifiers: its name and
/// how many of its types are collected (reviewed answers only) as a small
/// heading, then each type in its own box.
struct PrivacyCategoryBox: View {
    @Bindable var viewModel: AppPrivacyViewModel
    let category: PrivacyDataCategory
    let types: [PrivacyDataType]

    var body: some View {
        let mismatched = Set(viewModel.worksheet.mismatches.map(\.type))
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.small)
                Text(viewModel.collectedSummary(for: category))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .padding(.horizontal, Spacing.xxSmall)
            .padding(.top, Spacing.xxSmall)
            ForEach(types) { type in
                PrivacyDataTypeRow(viewModel: viewModel, type: type, isMismatched: mismatched.contains(type))
            }
            let hidden = viewModel.hiddenCount(in: category)
            if hidden > 0 {
                Button(String(localized: "\(hidden) more not collected")) {
                    viewModel.showsAllTypes = true
                }
                .buttonStyle(.link)
                .font(.subheadline)
                .padding(.horizontal, Spacing.xxSmall)
                .accessibilityIdentifier("appInformation.appPrivacy.category.\(category.rawValue).more")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.category.\(category.rawValue)")
    }
}
