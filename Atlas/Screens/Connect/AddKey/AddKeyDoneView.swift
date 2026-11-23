//
//  AddKeyDoneView.swift
//  Atlas
//

import SwiftUI

/// "Fieldworks Studio is connected": the new key is saved, its apps are in
/// the app switcher, and the person picks: keep the team in use, or switch
/// to the new one now.
struct AddKeyDoneView: View {
    let added: AddedKey
    let onKeep: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(Palette.ok)
                .accessibilityHidden(true)
            Text(added.title)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("addKey.done.title")
            Text(added.message)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
            if let line = added.appsLine {
                VStack(spacing: 6) {
                    ProgressView(value: 1)
                        .progressViewStyle(.linear)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(.footnote)
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
            .padding(.top, Spacing.xSmall)
        }
        .padding(Spacing.xxxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addKey.done")
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
    .frame(width: 580, height: 680)
}
