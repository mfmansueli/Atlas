//
//  AssistantChatTurn.swift
//  Atlas
//

import Foundation

/// One question in the chat and what came back: the person's words (a
/// question, a follow-up or a quick reply), the Claude Code run that
/// answers them, and how it ended.
struct AssistantChatTurn: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// Claude Code is starting or reading; the steps come from its run.
        case working
        /// The answer, and the suggestions it sent.
        case answered(text: String, suggestions: AssistantChatSuggestions?)
        /// The assistant asked something with `ask_in_chat` and waits.
        case needsYou(AssistantChatQuestion)
        /// The person pressed Stop. What it already suggested stays.
        case stopped
        case failed(ClaudeCodeRunFailure)
    }

    let id: UUID
    /// What the person wrote, or the quick reply they picked.
    var text: String
    var askedAt: Date
    /// Nil until the launcher started it.
    var runID: ClaudeCodeRun.ID?
    var state: State = .working
    /// When the answer, the question or the failure arrived.
    var endedAt: Date?

    var isWorking: Bool { state == .working }

    var question: AssistantChatQuestion? {
        if case let .needsYou(question) = state { return question }
        return nil
    }

    var failure: ClaudeCodeRunFailure? {
        if case let .failed(failure) = state { return failure }
        return nil
    }

    var suggestions: AssistantChatSuggestions? {
        if case let .answered(_, suggestions) = state { return suggestions }
        return nil
    }
}
