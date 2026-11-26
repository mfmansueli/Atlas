//
//  AutopilotBarHeader.swift
//  Atlas
//

import SwiftUI

/// The open bar's top line (board 80): ✦ Autopilot, Working while the
/// assistant answers, the context the next question goes with, and ⌄,
/// which makes the bar small again (also ⌘J and Esc).
struct AutopilotBarHeader: View {
    let isWorking: Bool
    let chips: [AssistantChatContext.Chip]
    let onClose: () -> Void
    let onRemoveChip: (String) -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            Text("Autopilot", comment: "kind:title · the open Autopilot bar")
                .atlasTextStyle(.headline)
                .fixedSize()
                .accessibilityAddTraits(.isHeader)
            if isWorking {
                Pill(text: String(localized: "Working", comment: "kind:pill · the assistant answers"), style: .machineTranslated)
                    .fixedSize()
                    .accessibilityIdentifier("chat.working")
            }
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xSmall) {
                    ForEach(chips) { chip in
                        AssistantChatChip(chip: chip) { onRemoveChip(chip.id) }
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            Button(action: onClose) {
                HStack(spacing: Spacing.xSmall) {
                    AssistantChatShortcutHint()
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.cancelAction)
            .help(Text("Make smaller (⌘J)", comment: "kind:tooltip · closes the open Autopilot bar"))
            .accessibilityLabel(Text("Make Autopilot smaller", comment: "kind:accessibility"))
            .accessibilityIdentifier("chat.close")
        }
        .padding(.leading, Spacing.large)
        .padding(.trailing, Spacing.medium)
        .padding(.vertical, Spacing.small)
    }
}

#Preview {
    AutopilotBarHeader(
        isWorking: true,
        chips: [.init(id: "app", label: "Lumen", isRemovable: false), .init(id: "version", label: "Version 1.4", isRemovable: true)],
        onClose: {}, onRemoveChip: { _ in }
    )
    .frame(width: Metrics.autopilotBarWidth)
}
