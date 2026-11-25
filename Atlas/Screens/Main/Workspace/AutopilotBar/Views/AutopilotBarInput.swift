//
//  AutopilotBarInput.swift
//  Atlas
//

import SwiftUI

/// The open Autopilot bar's field (board 80): where the closed one was,
/// with Send (blue, what you do) or Stop while the assistant answers.
/// Return sends; what's written stays as a draft when the bar closes.
struct AutopilotBarInput: View {
    @Binding var text: String
    let placeholder: String
    let isWorking: Bool
    let isEnabled: Bool
    /// Where a request's spark lands (effect 1, Trail).
    let anchor: AskAnchor
    @FocusState.Binding var isFocused: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    private var canSend: Bool {
        isEnabled && !isWorking && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                .background(AskAnchorView(anchor: anchor))
                .accessibilityHidden(true)
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .atlasTextStyle(.body)
                .lineLimit(1...4)
                .focused($isFocused)
                .disabled(!isEnabled)
                .onSubmit { if canSend { onSend() } }
                .padding(.vertical, Spacing.xSmall)
                .accessibilityLabel(Text("Message", comment: "kind:accessibility · the Autopilot bar's field"))
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
        .padding(.trailing, Spacing.small)
        .frame(minHeight: Metrics.autopilotBarFieldHeight)
    }
}
