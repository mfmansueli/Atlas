//
//  AssistantChatPrompt.swift
//  Atlas
//

import Foundation

/// What Claude Code is told for one turn of the chat: where the person is
/// (the context chips they kept) and their words. A follow-up continues
/// the session, so it says only what's new. How answers look is in the
/// run's system prompt (`ClaudeCodePermissions.chatPrompt`).
enum AssistantChatPrompt {
    static func prompt(
        _ text: String, context: AssistantChatContext, removed: Set<String>, isFollowUp: Bool, answers question: AssistantChatQuestion?
    ) -> String {
        var place = "The person is on the \(context.section.title) section of \(context.appName) (app ID \(context.appID)) in Atlas"
        if let version = context.version(removing: removed) { place += ", looking at version \(version)" }
        if let country = context.country(removing: removed) { place += ", with \(country) chosen as the country its prices show" }
        place += "."
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let question {
            return "\(place)\nYou asked: \(question.text)\nThey answer: \(words)"
        }
        if isFollowUp {
            return "\(place)\nTheir next message in the chat: \(words)"
        }
        return """
        \(place)
        They ask in Atlas's chat: \(words)
        Read what you need with Atlas's get_ and list_ tools (and this project's files), then answer.
        """
    }
}
