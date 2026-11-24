//
//  AskInChatTool.swift
//  Atlas
//

import Foundation

/// `ask_in_chat`: in a run started from Atlas's chat (board 69), the
/// assistant asks the person something it needs before it can answer.
/// The question shows in the chat with its choices as quick replies, the
/// closed chat says “Needs you”, and the person's answer starts the next
/// turn of the same session.
struct AskInChatTool: MCPTool {
    var center = AssistantChatCenter.shared

    let definition = MCPToolDefinition(
        name: "ask_in_chat",
        title: "Ask the person in Atlas's chat",
        description: """
        Only in a session started from Atlas's chat: asks the person something you need before you can answer, such as \
        which products to count. Give `question` (at most \(AssistantTextLimits.titleWords) words, e.g. “Count every \
        product, or only subscriptions?”) and \(AssistantChatQuestion.choiceRange.lowerBound) to \
        \(AssistantChatQuestion.choiceRange.upperBound) `choices` (each at most \(AssistantChatQuestion.choiceCharacters) \
        characters, in Title Case, e.g. “Only Subscriptions”). Then end your turn: the person's answer arrives as the next \
        message of this session. Ask only what changes the answer, at most once per question.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "question": MCPToolDefinition.string("What you need to know, at most \(AssistantTextLimits.titleWords) words."),
                "choices": [
                    "type": "array",
                    "description": .string(
                        "\(AssistantChatQuestion.choiceRange.lowerBound) to \(AssistantChatQuestion.choiceRange.upperBound) short answers, shown as buttons."
                    ),
                    "items": ["type": "string"],
                ],
            ],
            required: ["appId", "question", "choices"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = "\(app.name) · Chat"
        let question = try arguments.string("question").trimmingCharacters(in: .whitespacesAndNewlines)
        let choices = try (arguments.optionalStrings("choices") ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let refused = Self.refusal(question: question, choices: choices) { return .refused(refused, target: target) }
        guard center.receive(AssistantChatQuestion(text: question, choices: choices), for: app.id) else {
            return .refused("\(app.name) has no chat waiting for an answer: ask_in_chat works only in a session started from Atlas's chat.", target: target)
        }
        return MCPToolOutcome(
            result: ["status": "shown", "next": "End your turn now. The person's answer arrives as the next message."],
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .read)]
        )
    }

    /// Why the question can't be shown, in words the assistant can act on.
    static func refusal(question: String, choices: [String]) -> String? {
        if let refusal = AssistantTextLimits.titleRefusal(question, field: "question") { return refusal }
        let range = AssistantChatQuestion.choiceRange
        guard range.contains(choices.count) else {
            return "choices has \(choices.count); give \(range.lowerBound) to \(range.upperBound)."
        }
        if let empty = choices.firstIndex(where: \.isEmpty) { return "choices[\(empty)] is empty." }
        if let long = choices.firstIndex(where: { $0.count > AssistantChatQuestion.choiceCharacters }) {
            return "choices[\(long)] is \(choices[long].count) characters; at most \(AssistantChatQuestion.choiceCharacters)."
        }
        if Set(choices.map { $0.lowercased() }).count < choices.count { return "Two choices are the same." }
        return nil
    }
}
