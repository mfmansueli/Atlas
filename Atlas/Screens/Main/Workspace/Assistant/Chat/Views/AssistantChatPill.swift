//
//  AssistantChatPill.swift
//  Atlas
//

import SwiftUI

/// The closed chat (board 69): a small pill in the content's bottom-right
/// corner that says in one line what's happening, or how to ask. A click
/// (or ⌘J) opens the conversation; Connect… and Try Again act at once.
struct AssistantChatPill: View {
    let line: AssistantChatPillLine
    let client: String
    let onOpen: () -> Void
    let onAction: (AssistantChatPillLine.Action) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: Spacing.small) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.small) {
                    AssistantChatLead(lead: line.lead)
                    Text(line.text)
                        .atlasTextStyle(.body)
                        .foregroundStyle(line.isPlaceholder ? Palette.label2 : Palette.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let detail = line.detail {
                        Text(detail)
                            .atlasTextStyle(.callout)
                            .foregroundStyle(Palette.label2)
                            .monospacedDigit()
                            .fixedSize()
                    }
                    if let progress = line.progress {
                        MeterBar(fraction: progress, tint: Palette.accent, height: Spacing.xxSmall)
                            .frame(width: Metrics.chatMeterWidth)
                    }
                    tag
                    if line.showsShortcut { AssistantChatShortcutHint() }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(line.accessibilityLabel(client: client)))
            .accessibilityHint(Text("Opens the chat", comment: "kind:accessibility"))
            .accessibilityIdentifier("chat.pill")
            if let action = line.action, let title = line.actionTitle {
                Button(title) { onAction(action) }
                    .controlSize(.small)
                    .accessibilityIdentifier("chat.pill.action")
            }
            Image(systemName: "chevron.up")
                .imageScale(.small)
                .foregroundStyle(Palette.label2)
                .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
                .accessibilityHidden(true)
        }
        .padding(.leading, Spacing.medium)
        .padding(.trailing, Spacing.xSmall)
        .frame(width: Metrics.chatPillWidth, height: Metrics.chatPillHeight)
        .background {
            if reduceTransparency {
                Capsule().fill(Palette.raised)
            }
        }
        .glassEffect(reduceTransparency ? .identity : .regular, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.separator, lineWidth: 0.5) }
        .depth(.popover)
        .aiNeedsYou(line.tag == .needsYou)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.closed")
    }

    @ViewBuilder
    private var tag: some View {
        if let text = line.tagText {
            switch line.tag {
            case .needsYou:
                // The only filled purple in the chat: the assistant waits.
                Text(text)
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.aiFillLabel)
                    .padding(.horizontal, Spacing.small)
                    .frame(minHeight: Spacing.xLarge)
                    .background(Palette.aiFill, in: Capsule())
                    .fixedSize()
            case .suggestions:
                Pill(text: text, style: .machineTranslated).fixedSize()
            case .answer, nil:
                Pill(text: text).fixedSize()
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.medium) {
        AssistantChatPill(
            line: AssistantChatPillLine(lead: .sparkles, text: "Ask about Lumen…", isPlaceholder: true, showsShortcut: true),
            client: "Claude Code", onOpen: {}, onAction: { _ in }
        )
        AssistantChatPill(
            line: AssistantChatPillLine(lead: .dot(.working), text: "Read store page", detail: "Step 2"),
            client: "Claude Code", onOpen: {}, onAction: { _ in }
        )
        AssistantChatPill(
            line: AssistantChatPillLine(lead: .dot(.arrived), text: "Every product or subscriptions?", tag: .needsYou),
            client: "Claude Code", onOpen: {}, onAction: { _ in }
        )
        AssistantChatPill(
            line: AssistantChatPillLine(lead: .dot(.failure), text: "Claude Code stopped", action: .tryAgain),
            client: "Claude Code", onOpen: {}, onAction: { _ in }
        )
    }
    .padding()
}
