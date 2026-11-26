//
//  AppInformationAcceptsRightAwayLine.swift
//  Atlas
//

import SwiftUI

/// Under the page strip while "Don't ask again" is on and something waits:
/// Accept All Pages accepts at once, with Ask First to see them again.
struct AppInformationAcceptsRightAwayLine: View {
    @Bindable var viewModel: AppInformationViewModel

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        if viewModel.isLoaded, preferences.acceptsAllWithoutAsking, totalCount > 0 {
            HStack(spacing: Spacing.small) {
                Pill(text: String(localized: "Accepts right away", comment: "kind:pill · Accept All Pages doesn't ask first"), style: .accent)
                    .fixedSize()
                Text("Accept All Pages doesn’t ask first.", comment: "kind:caption · App Information, Accept All Pages accepts at once")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                Button(String(localized: "Ask First", comment: "kind:button · Accept All Pages shows the suggestions first again")) {
                    preferences.acceptsAllWithoutAsking = false
                    viewModel.suggestionToast = ToastMessage(text: String(localized: "Accept All shows the suggestions first again."))
                }
                .buttonStyle(.link)
                .atlasTextStyle(.subheadline)
                .accessibilityIdentifier("appInformation.askFirst")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appInformation.acceptsRightAway")
        }
    }

    private var totalCount: Int {
        viewModel.pageBarModel(on: viewModel.page, acceptsRightAway: true).totalCount
    }
}
