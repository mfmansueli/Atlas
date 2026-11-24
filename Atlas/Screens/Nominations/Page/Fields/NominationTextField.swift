//
//  NominationTextField.swift
//  Atlas
//

import SwiftUI

/// A nomination's text (name, description or notes) with its count:
/// "142 characters · limit not confirmed", since Apple publishes no
/// limits. A refused description is outlined in amber.
struct NominationTextField: View {
    let placeholder: String
    @Binding var text: String
    var isRequired = false
    var isMultiline = false
    var isFlagged = false
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Group {
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(4...10)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .padding(Spacing.small)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(isFlagged ? Palette.warn : Palette.separator, lineWidth: isFlagged ? 1 : 0.5)
            }
            .accessibilityIdentifier(identifier)
            Text(Self.count(text, isRequired: isRequired))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("\(identifier).count")
        }
    }

    /// "Required · limit not confirmed" while empty, else "12 characters ·
    /// limit not confirmed".
    static func count(_ text: String, isRequired: Bool) -> String {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        if count == 0, isRequired { return String(localized: "Required · limit not confirmed", comment: "kind:description") }
        return count == 1
            ? String(localized: "1 character · limit not confirmed", comment: "kind:description")
            : String(localized: "\(count) characters · limit not confirmed", comment: "kind:description")
    }
}
