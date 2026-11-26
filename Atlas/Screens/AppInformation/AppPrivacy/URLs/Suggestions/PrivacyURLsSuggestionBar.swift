//
//  PrivacyURLsSuggestionBar.swift
//  Atlas
//

import SwiftUI

/// Over Privacy URLs while User Privacy Choices URLs are suggested: the
/// arrows to the languages with one, and why only the URLs are here. Accept
/// n on This Page and Accept All Pages are at the top of the section.
struct PrivacyURLsSuggestionBar: View {
    @Bindable var viewModel: AppInformationViewModel

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.small) {
            Label {
                Text(
                    "Only for User Privacy Choices URLs. You review App Privacy answers one by one in the worksheet.",
                    comment: "kind:caption · App Privacy, what the suggestions on Privacy URLs cover"
                )
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock")
                    .imageScale(.small)
            }
            .atlasTextStyle(.subheadline)
            .foregroundStyle(Palette.label2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("appInformation.appPrivacy.barNote")
            PrivacyURLsSuggestionArrows(navigation: viewModel.privacySuggestionNavigation) { viewModel.showPrivacySuggestion($0) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.appPrivacy.suggestionBar")
    }
}
