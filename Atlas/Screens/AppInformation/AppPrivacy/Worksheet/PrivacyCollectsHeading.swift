//
//  PrivacyCollectsHeading.swift
//  Atlas
//

import SwiftUI

/// "What Lumen collects" over the data types, with Scan the Code Again…
/// (AI work started from the page: secondary, sparkle, purple) and Accept
/// N High-Confidence (a row action, tinted), which skips conflicts and
/// types with an open question and hides when there's nothing to accept.
struct PrivacyCollectsHeading: View {
    let viewModel: AppPrivacyViewModel

    var body: some View {
        HStack(spacing: Spacing.small) {
            Text("What \(viewModel.appShortName) collects", comment: "kind:section-title")
                .font(.callout.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            PrivacyScanAgainButton(viewModel: viewModel)
            let count = viewModel.highConfidenceCount
            if count > 0 {
                Button(String(localized: "Accept \(count) High-Confidence", comment: "kind:button")) {
                    viewModel.acceptAllHighConfidence()
                }
                .rowActionButton()
                .accessibilityIdentifier("appInformation.appPrivacy.acceptHighConfidence")
            }
        }
        .controlSize(.regular)
    }
}
