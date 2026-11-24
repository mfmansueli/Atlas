//
//  AssistantChatPanel.swift
//  Atlas
//

import SwiftUI

/// The open chat (board 69): a small window in the content's corner, over
/// what's there, that never reaches the toolbar. The title and context,
/// the conversation (or three questions to start), and the field.
struct AssistantChatPanel: View {
    let chat: AssistantChat
    let context: AssistantChatContext
    let client: String
    let canAsk: Bool
    /// The working turn's steps so far.
    let steps: [AssistantChatStep]
    let height: CGFloat
    @Binding var draft: String
    let onSend: (String) -> Void
    let onStop: () -> Void
    let onRetry: () -> Void
    let onShowOutput: (ClaudeCodeRun.ID) -> Void
    let onClose: () -> Void
    let onConnect: () -> Void
    let onShow: (AppWorkspaceSection) -> Void
    let onRemoveChip: (String) -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            AssistantChatHeader(
                client: client, isWorking: chat.isWorking, chips: context.chips(removing: chat.removedContext),
                onClose: onClose, onRemoveChip: onRemoveChip
            )
            Divider()
            conversation
            AssistantChatInput(
                text: $draft, placeholder: placeholder, isWorking: chat.isWorking, isEnabled: canAsk,
                isFocused: $isFieldFocused, onSend: { onSend(draft) }, onStop: onStop
            )
            .padding(.horizontal, Spacing.medium)
            .padding(.top, Spacing.xSmall)
            .padding(.bottom, note == nil ? Spacing.medium : Spacing.xSmall)
            if let note {
                Text(note)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.large)
                    .padding(.bottom, Spacing.small)
                    .accessibilityIdentifier("chat.note")
            }
        }
        .frame(width: Metrics.chatPanelWidth, height: height)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
                .strokeBorder(Palette.separator, lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .depth(.popover)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(client))
        .accessibilityIdentifier("chat.panel")
        .onAppear { if canAsk { isFieldFocused = true } }
    }

    @ViewBuilder
    private var conversation: some View {
        if chat.turns.isEmpty {
            AssistantChatEmptyState(
                appName: context.appName, client: client, canAsk: canAsk,
                starters: AssistantChatStarters.starters(for: context.section), onAsk: onSend, onConnect: onConnect
            )
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.medium)
        } else {
            ScrollView {
                // Not lazy: XCUITest's and VoiceOver's reads of a LazyVStack
                // under these cards recurse until SwiftUI crashes (as on
                // App Privacy, 2026-11-23), and a chat holds few turns.
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    ForEach(chat.turns) { turn in
                        AssistantChatPersonBubble(text: turn.text)
                        AssistantChatReply(
                            turn: turn, steps: turn.isWorking ? steps : [], client: client, isLast: turn.id == chat.last?.id,
                            onReply: onSend, onRetry: onRetry,
                            onShowOutput: turn.runID.map { id in { onShowOutput(id) } },
                            onShow: onShow
                        )
                        .id(turn.id)
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.vertical, Spacing.medium)
            }
            .defaultScrollAnchor(.bottom)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var placeholder: String {
        if !canAsk { return String(localized: "No assistant connected", comment: "kind:placeholder · the chat's field") }
        if chat.question != nil { return String(localized: "Or write your answer…", comment: "kind:placeholder · the chat's field") }
        if chat.turns.isEmpty { return String(localized: "Ask about \(context.appName)…", comment: "kind:placeholder · the chat's field") }
        return String(localized: "Ask a follow-up…", comment: "kind:placeholder · the chat's field")
    }

    /// The safety line, once: under an answer that suggested something.
    private var note: String? {
        guard let section = chat.last?.suggestions?.section else { return nil }
        return String(localized: "Accept them in \(section.title). Nothing is sent until you push.", comment: "kind:footnote · under a chat answer's suggestions")
    }
}
