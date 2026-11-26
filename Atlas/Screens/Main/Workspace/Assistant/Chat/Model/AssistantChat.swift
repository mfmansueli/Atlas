//
//  AssistantChat.swift
//  Atlas
//

import Foundation

/// One app's conversation in the Autopilot bar (board 80, from board 69):
/// its turns, the Claude Code session its follow-ups continue, the draft
/// kept while the panel is closed, and whether something arrived unseen.
struct AssistantChat: Hashable, Sendable {
    var turns: [AssistantChatTurn] = []
    /// Claude Code's session, so a follow-up goes on from the last answer.
    var sessionID: String?
    /// What the person was writing: closing the panel keeps it.
    var draft = ""
    /// An answer or a question arrived while the panel was closed.
    var isUnseen = false
    /// The context chips the person took out, by `AssistantChatContext.Chip.id`.
    var removedContext: Set<String> = []

    var last: AssistantChatTurn? { turns.last }

    var isWorking: Bool { last?.isWorking == true }

    /// What the assistant waits for the person to answer.
    var question: AssistantChatQuestion? { last?.question }

    var hasDraft: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
