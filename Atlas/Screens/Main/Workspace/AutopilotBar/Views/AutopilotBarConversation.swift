//
//  AutopilotBarConversation.swift
//  Atlas
//

import SwiftUI

/// The open bar's conversation (board 80): each typed question and its
/// answer (the steps while it works, then the answer and the card of what
/// it suggested, with Accept), and the request a button sent while it
/// runs, as the person's bubble over its steps. Empty, three questions to
/// start; without an assistant, how to connect one.
struct AutopilotBarConversation: View {
    let chat: AssistantChat
    let progress: AssistantChatProgress
    let client: String
    let appName: String
    let canAsk: Bool
    let starters: [String]
    /// The request a button sent, while its run works.
    var sent: AutopilotBarRequest?
    var sentSubject: String?
    var sentProgress = AssistantChatProgress()
    let onSend: (String) -> Void
    let onRetry: () -> Void
    let onShowOutput: (ClaudeCodeRun.ID) -> Void
    let onShow: (AssistantChatSuggestions) -> Void
    let onConnect: () -> Void

    var body: some View {
        // Not lazy: XCUITest's and VoiceOver's reads of a LazyVStack under
        // these cards recurse until SwiftUI crashes (as on App Privacy,
        // 2026-11-23), and a conversation holds few turns.
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if chat.turns.isEmpty, sent == nil {
                AssistantChatEmptyState(
                    appName: appName, client: client, canAsk: canAsk, starters: starters, onAsk: onSend, onConnect: onConnect
                )
            }
            ForEach(chat.turns) { turn in
                AssistantChatPersonBubble(text: turn.text)
                AssistantChatReply(
                    turn: turn, progress: turn.isWorking ? progress : AssistantChatProgress(), client: client, isLast: turn.id == chat.last?.id,
                    onReply: onSend, onRetry: onRetry,
                    onShowOutput: turn.runID.map { id in { onShowOutput(id) } },
                    onShow: onShow
                )
                .id(turn.id)
            }
            if let sent {
                AssistantChatPersonBubble(text: sent.text(subject: sentSubject))
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Label {
                        Text(client)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                    AssistantChatStepsList(progress: sentProgress, client: client)
                    Text("Its suggestions show up in purple where they go.", comment: "kind:status · under a request the Autopilot bar sent")
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(sent.id)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.conversation")
    }
}
