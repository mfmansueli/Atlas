//
//  AddKeyCheckingView.swift
//  Atlas
//

import SwiftUI

/// "Checking the new key…" (the canvas's Welcome `addkey-check`): while
/// App Store Connect answers for another team's key, the sheet brings the
/// large welcome header back and says what is being checked and that the
/// team in use stays as it is. Cancel stops the check and goes back to the
/// filled form; nothing is saved.
struct AddKeyCheckingView: View {
    let keptTeam: String
    /// The sheet's size decides the header's height and the text sizes.
    var layout = WelcomeLayout(windowSize: AddKeySheetLayout.preferred)
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Still: the bar below is the one thing moving (one loop on
            // screen).
            WelcomeHeader(style: .large, markSize: layout.largeMarkSize, forcesStill: true)
                .frame(height: layout.largeHeaderHeight)
            content
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addKey.checking")
    }

    private var content: some View {
        VStack(spacing: layout.isShort ? Spacing.small : Spacing.medium) {
            Text(AddKeyCopy.checkingTitle)
                .atlasTextStyle(layout.isShort ? .largeTitle : .display)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("addKey.checking.title")
            Text(AddKeyCopy.checkingMessage(keeping: keptTeam))
                .atlasTextStyle(layout.isShort ? .body : .title3)
                .fontWeight(.regular)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520)
            // No count to show: one request answers with the team and its
            // apps, so the bar doesn't pretend to measure it.
            ProgressView()
                .progressViewStyle(.linear)
                .frame(width: 360)
                .accessibilityLabel(Text(AddKeyCopy.checkingProgress))
            Button("Cancel", action: onCancel)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("addKey.checking.cancel")
        }
        .padding(.top, layout.isShort ? Spacing.medium : Spacing.xLarge)
        .padding(.horizontal, Spacing.xxxLarge)
        .padding(.bottom, Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AddKeyCheckingView(keptTeam: "Northpier Studio") {}
        .frame(width: 920, height: 700)
}
