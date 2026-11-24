//
//  AssistantChatReply.swift
//  Atlas
//

import SwiftUI

/// The assistant's side of a turn, under its name in purple: the steps
/// while it works, then the answer and the card of what it suggested, a
/// question with quick replies, a failure, or “Stopped”.
struct AssistantChatReply: View {
    let turn: AssistantChatTurn
    /// The working turn's steps so far.
    let steps: [AssistantChatStep]
    let client: String
    /// The last turn: only its question takes quick replies.
    let isLast: Bool
    let onReply: (String) -> Void
    let onRetry: () -> Void
    let onShowOutput: (() -> Void)?
    let onShow: (AppWorkspaceSection) -> Void

    var body: some View {
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
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch turn.state {
        case .working:
            AssistantChatStepsList(steps: steps, client: client)
        case let .answered(text, suggestions):
            VStack(alignment: .leading, spacing: Spacing.small) {
                if !text.isEmpty {
                    Text(Self.markdown(text))
                        .atlasTextStyle(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("chat.answer")
                }
                if let suggestions {
                    AssistantChatSuggestionCard(suggestions: suggestions, client: client, onShow: onShow)
                }
            }
            .aiArrived(key: "chat.\(turn.id.uuidString)", arrivedAt: turn.endedAt)
        case let .needsYou(question):
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(question.text)
                    .atlasTextStyle(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat.question")
                if isLast {
                    FlowLayout(spacing: Spacing.xSmall) {
                        ForEach(question.choices, id: \.self) { choice in
                            Button(choice) { onReply(choice) }
                                .rowActionButton()
                                .accessibilityIdentifier("chat.quickReply")
                        }
                    }
                }
            }
            .aiArrived(key: "chat.\(turn.id.uuidString)", arrivedAt: turn.endedAt)
        case .stopped:
            Text("Stopped. What it already suggested stays.", comment: "kind:status · a chat answer the person stopped")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("chat.stopped")
        case let .failed(failure):
            AssistantChatFailureCard(failure: failure, client: client, onRetry: onRetry, onShowOutput: onShowOutput)
        }
    }

    /// Bold, italics, code and links from the answer; anything else as
    /// written.
    static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
