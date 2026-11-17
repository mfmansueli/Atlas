//
//  InAppEventFieldBox.swift
//  Atlas
//

import SwiftUI

/// One of an event's three texts in the language being viewed: its
/// counter, the field, and the suggested text under it while one waits.
struct InAppEventFieldBox: View {
    let field: InAppEventField
    @Binding var text: String
    /// What people see while the field is empty: the primary language's.
    let placeholder: String
    /// The suggested text for this field, while a suggestion waits.
    let suggested: String?
    let isEditable: Bool
    let isPending: Bool
    let isRightToLeft: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                if isPending {
                    UnsavedDot(size: 6)
                }
                Text(field.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                counter
            }
            Group {
                if field.isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(2...4)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.callout)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(Palette.content, in: shape)
            .overlay(shape.strokeBorder(isOver ? Palette.danger : Palette.separator2, lineWidth: isOver ? 1.5 : 1))
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
            .disabled(!isEditable)
            .accessibilityLabel(Text(field.title))
            .accessibilityIdentifier("events.field.\(field.rawValue)")
            if let suggested {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text("SUGGESTED")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.machineTranslated)
                    Text(suggested)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                        .accessibilityIdentifier("events.field.\(field.rawValue).suggested")
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(suggested == nil ? Palette.separator : Palette.machineTranslatedMark.opacity(0.55), lineWidth: suggested == nil ? 0.5 : 1)
        )
    }

    private var isOver: Bool { text.count > field.limit }

    @ViewBuilder
    private var counter: some View {
        let label = "\(text.count) / \(field.limit)"
        if isOver {
            Pill(text: label, style: .danger)
        } else {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("events.field.\(field.rawValue).counter")
        }
    }
}
