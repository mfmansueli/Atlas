//
//  InAppEventFieldBox.swift
//  Atlas
//

import SwiftUI

/// One of an event's three texts in the language being viewed: its
/// counter, the field, what App Review would reject in it (a warning: the
/// person may know better), and the suggested text under it while one
/// waits. It takes focus for a revision's Use and Edit.
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
    /// Set to take focus: a revision's Use and Edit. `onFocusTaken` clears it.
    var takesFocus = false
    var onFocusTaken: () -> Void = {}

    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.xSmall) {
                if isPending {
                    UnsavedDot(size: 6)
                }
                Text(field.title)
                    .font(.body.weight(.semibold))
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
            .overlay(shape.strokeBorder(isOver ? Palette.err : Palette.separator2, lineWidth: isOver ? 1.5 : 1))
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
            .disabled(!isEditable)
            .focused($isFocused)
            .onChange(of: takesFocus, initial: true) {
                guard takesFocus else { return }
                isFocused = true
                onFocusTaken()
            }
            .accessibilityLabel(Text(field.title))
            .accessibilityIdentifier("events.field.\(field.rawValue)")
            let issues = StoreTextGuidelineCheck.issues(in: text, for: .eventText)
            if !issues.isEmpty {
                InlineMessage.warning(issues.map(\.message).joined(separator: "\n"))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.field.\(field.rawValue).guideline")
            }
            if let suggested {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text("SUGGESTED")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ai)
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
                .strokeBorder(suggested == nil ? Palette.separator : Palette.aiMark.opacity(0.55), lineWidth: suggested == nil ? 0.5 : 1)
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
                .font(.footnote.monospaced())
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("events.field.\(field.rawValue).counter")
        }
    }
}
