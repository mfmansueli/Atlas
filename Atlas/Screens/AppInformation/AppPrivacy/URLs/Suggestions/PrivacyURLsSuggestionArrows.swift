//
//  PrivacyURLsSuggestionArrows.swift
//  Atlas
//

import SwiftUI

/// In App Privacy's suggestion bar: arrows to the previous or next language
/// whose User Privacy Choices URL has a suggestion, as the Store Page's
/// language bar has, and which one is in view.
struct PrivacyURLsSuggestionArrows: View {
    let navigation: PrivacyURLsSuggestionNavigation
    let onSelect: (StoreLocale) -> Void

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            ControlGroup {
                arrow(navigation.previous, systemImage: "chevron.left", title: String(localized: "Previous language with suggestions"))
                    .accessibilityIdentifier("appInformation.appPrivacy.previous")
                arrow(navigation.next, systemImage: "chevron.right", title: String(localized: "Next language with suggestions"))
                    .accessibilityIdentifier("appInformation.appPrivacy.next")
            }
            .fixedSize()
            if let position = navigation.positionText {
                Text(position)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .accessibilityIdentifier("appInformation.appPrivacy.position")
            }
        }
    }

    private func arrow(_ locale: StoreLocale?, systemImage: String, title: String) -> some View {
        let help = locale.map { "\(title): \($0.name)" } ?? title
        return Button {
            if let locale { onSelect(locale) }
        } label: {
            Image(systemName: systemImage)
        }
        .disabled(locale == nil || !navigation.canMove)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}
