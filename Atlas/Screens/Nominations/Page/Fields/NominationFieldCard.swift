//
//  NominationFieldCard.swift
//  Atlas
//

import SwiftUI

/// One part of a nomination's page: its title, a line under it, "Suggested"
/// when an assistant's nomination filled it, a note on the right
/// ("Optional", "Links only"), and the field.
struct NominationFieldCard<Content: View>: View {
    let title: String
    var subtitle: String?
    var trailingNote: String?
    var isSuggested = false
    var identifier: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Text(title)
                    .font(.headline)
                if isSuggested {
                    Pill(text: String(localized: "Suggested", comment: "kind:pill"), style: .machineTranslated)
                        .fixedSize()
                }
                Spacer(minLength: Spacing.xSmall)
                if let trailingNote {
                    Text(trailingNote)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .accessibilityIdentifier(identifier)
    }
}
