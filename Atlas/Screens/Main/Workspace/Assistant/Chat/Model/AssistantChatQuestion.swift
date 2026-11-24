//
//  AssistantChatQuestion.swift
//  Atlas
//

import Foundation

/// What the assistant asks the person in the chat, with `ask_in_chat`
/// (board 69, “Needs you”): a short question and the choices it shows as
/// quick replies. The person can also write an answer of their own.
struct AssistantChatQuestion: Hashable, Sendable {
    /// At most 8 words: the pill shows it when the panel is closed.
    var text: String
    /// Two to four, each a button.
    var choices: [String]

    static let choiceRange = 2...4
    /// The longest a choice may be, so four fit on two rows of the panel.
    static let choiceCharacters = 28
}
