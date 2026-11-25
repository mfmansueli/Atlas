//
//  AddKeyDoneView.swift
//  Atlas
//

import SwiftUI

/// "Fieldworks Studio is connected" (the canvas's Welcome `addkey-done`):
/// under the large welcome header, the new key is saved, its apps are in
/// the app switcher, and the person picks: keep the team in use, or switch
/// to the new one now.
struct AddKeyDoneView: View {
    let added: AddedKey
    /// The sheet's size decides the header's height and the text sizes.
    var layout = WelcomeLayout(windowSize: AddKeySheetLayout.preferred)
    let onKeep: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            WelcomeHeader(style: .large, markSize: layout.largeMarkSize)
                .frame(height: layout.largeHeaderHeight)
            content
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addKey.done")
    }

    private var content: some View {
        VStack(spacing: layout.isShort ? Spacing.small : Spacing.medium) {
            Text(added.title)
                .atlasTextStyle(layout.isShort ? .largeTitle : .display)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("addKey.done.title")
            Text(added.message)
                .atlasTextStyle(layout.isShort ? .body : .title3)
                .fontWeight(.regular)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520)
            if let line = added.appsLine {
                VStack(spacing: Spacing.xSmall) {
                    ProgressView(value: 1)
                        .progressViewStyle(.linear)
                        .accessibilityHidden(true)
                    Text(line)
                        .atlasTextStyle(.footnote)
                        .foregroundStyle(Palette.label2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: 360)
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: Spacing.small) {
                Button(added.keepTitle, action: onKeep)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("addKey.done.keep")
                Button(added.switchTitle, action: onSwitch)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("addKey.done.switch")
            }
            .controlSize(.large)
        }
        .padding(.top, layout.isShort ? Spacing.medium : Spacing.xLarge)
        .padding(.horizontal, Spacing.xxxLarge)
        .padding(.bottom, Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AddKeyDoneView(
        added: AddedKey(
            keyID: "7QK2M8ZP1D",
            check: KeyAccessCheck(
                appCount: 3, milliseconds: 180, salesAccess: .readable, date: .now,
                appNames: ["Trailhead", "Ledgerly", "Kiln"], teamName: "Fieldworks Studio"
            ),
            keptTeam: "Northpier Studio"
        ),
        onKeep: {},
        onSwitch: {}
    )
    .frame(width: 920, height: 700)
}
