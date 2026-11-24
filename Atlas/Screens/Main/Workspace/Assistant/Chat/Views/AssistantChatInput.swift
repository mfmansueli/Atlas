//
//  AssistantChatInput.swift
//  Atlas
//

import SwiftUI

/// The field at the bottom of the panel, with Send (blue, what you do) or
/// Stop while the assistant answers. Return sends; the text stays as a
/// draft when the panel closes.
struct AssistantChatInput: View {
    @Binding var text: String
    let placeholder: String
    let isWorking: Bool
    let isEnabled: Bool
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    private var canSend: Bool {
        isEnabled && !isWorking && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.small) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .atlasTextStyle(.body)
                .lineLimit(1...4)
                .focused($isFocused)
                .disabled(!isEnabled)
                .onSubmit { if canSend { onSend() } }
                .padding(.vertical, Spacing.xSmall)
                .accessibilityLabel(Text("Message", comment: "kind:accessibility · the chat's field"))
                .accessibilityIdentifier("chat.field")
            if isWorking {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .imageScale(.small)
                        .foregroundStyle(Palette.label)
                        .frame(width: Metrics.chatButtonSize, height: Metrics.chatButtonSize)
                        .background(Palette.fill2, in: Circle())
                }
                .buttonStyle(.plain)
                .help(Text("Stop", comment: "kind:tooltip"))
                .accessibilityLabel(Text("Stop", comment: "kind:accessibility"))
                .accessibilityIdentifier("chat.stop")
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .fontWeight(.semibold)
                        .foregroundStyle(canSend ? Color.white : Palette.label3)
                        .frame(width: Metrics.chatButtonSize, height: Metrics.chatButtonSize)
                        .background(canSend ? Palette.accent : Palette.fill2, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help(Text("Send (Return)", comment: "kind:tooltip"))
                .accessibilityLabel(Text("Send", comment: "kind:accessibility"))
                .accessibilityIdentifier("chat.send")
            }
        }
        .padding(.leading, Spacing.medium)
        .padding(.trailing, Spacing.xSmall)
        .padding(.vertical, Spacing.xSmall)
        .background(Palette.content, in: RoundedRectangle(cornerRadius: Radius.popover, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.popover, style: .continuous)
                .strokeBorder(isFocused ? Palette.accent : Palette.separator2, lineWidth: isFocused ? 1 : 0.5)
        }
    }
}
