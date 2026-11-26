//
//  ActionToast.swift
//  Atlas
//

import SwiftUI

/// What an action did, at the bottom of a section for a few seconds, with
/// Undo when it can be taken back. Nothing asks for confirmation first:
/// the toast is how the person takes a batch back. A toast can also offer
/// to go on (its message's `actionTitle`). VoiceOver announces it.
struct ActionToast: View {
    let message: ToastMessage
    /// How long it stays; a toast with Undo stays longer, to reach it.
    var duration: Duration?
    var onUndo: () -> Void = {}
    var onAction: () -> Void = {}
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The closed Autopilot bar's room at a section's bottom: the toast
    /// sits above it (0 where there's no bar).
    @Environment(\.chatCornerRoom) private var barRoom

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text(message.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("toast.text")
            if message.canUndo {
                // What comes back slides down into its place (effect 4).
                Button("Undo") { AIDecided.undo(reduceMotion: reduceMotion, commit: onUndo) }
                    .controlSize(.regular)
                    .accessibilityIdentifier("toast.undo")
            }
            if let actionTitle = message.actionTitle {
                Button(actionTitle, action: onAction)
                    .controlSize(.regular)
                    .accessibilityIdentifier("toast.action")
            }
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + 2)
        .frame(maxWidth: 560)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
                .strokeBorder(Palette.separator2, lineWidth: 0.5)
        }
        .depth(.popover)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast")
        .task(id: message.id) {
            AccessibilityNotification.Announcement(message.text).post()
            try? await Task.sleep(for: duration ?? (message.canUndo || message.actionTitle != nil ? .seconds(10) : .seconds(6)))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
        .padding(.bottom, barRoom)
    }
}

#Preview {
    VStack(spacing: Spacing.medium) {
        ActionToast(message: ToastMessage(text: "Accepted 5 suggestions in German. Nothing is sent yet.", canUndo: true)) {}
        ActionToast(message: ToastMessage(text: "Claude Code sent 4 suggestions. Nothing changes until you accept them.")) {}
    }
    .padding()
}
