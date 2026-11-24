//
//  AssistantChatHeader.swift
//  Atlas
//

import SwiftUI

/// The panel's title: the assistant's name (and Working while it
/// answers), ⌘J and the arrow that closes it (also Esc), then the
/// context the next question goes with.
struct AssistantChatHeader: View {
    let client: String
    let isWorking: Bool
    let chips: [AssistantChatContext.Chip]
    let onClose: () -> Void
    let onRemoveChip: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                Text(client)
                    .atlasTextStyle(.headline)
                    .accessibilityAddTraits(.isHeader)
                if isWorking {
                    Pill(text: String(localized: "Working", comment: "kind:pill · the chat's assistant answers"), style: .machineTranslated)
                        .accessibilityIdentifier("chat.working")
                }
                Spacer(minLength: 0)
                AssistantChatShortcutHint()
                Button(action: onClose) {
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
                .help(Text("Close (Esc)", comment: "kind:tooltip"))
                .accessibilityLabel(Text("Close the chat", comment: "kind:accessibility"))
                .accessibilityIdentifier("chat.close")
            }
            FlowLayout(spacing: Spacing.xSmall) {
                ForEach(chips) { chip in
                    AssistantChatChip(chip: chip) { onRemoveChip(chip.id) }
                }
            }
        }
        .padding(.leading, Spacing.large)
        .padding(.trailing, Spacing.medium)
        .padding(.vertical, Spacing.medium)
    }
}

#Preview {
    AssistantChatHeader(
        client: "Claude Code", isWorking: true,
        chips: [.init(id: "app", label: "Lumen", isRemovable: false), .init(id: "version", label: "Version 1.4", isRemovable: true)],
        onClose: {}, onRemoveChip: { _ in }
    )
    .frame(width: Metrics.chatPanelWidth)
}
